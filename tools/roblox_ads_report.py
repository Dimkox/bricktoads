"""Build a Russian-language report from UTC bucketed Roblox metrics."""
import math
import statistics
from datetime import timedelta, timezone


IMPRESSIONS = "SponsoredAdsImpressions"
CLICKS = "SponsoredAdsClicks"
SPEND = "SponsoredAdsSpendUsd"
PEAK = "PeakConcurrentPlayers"
SAMPLED = "ObservedConcurrentPlayers"
DAU = "DailyActiveUsers"
VISITS = "Visits"

AD_METRICS = (IMPRESSIONS, CLICKS, SPEND)
LABELS = {
    IMPRESSIONS: "Показы",
    CLICKS: "Клики",
    SPEND: "Расход",
    PEAK: "Пиковый онлайн",
    SAMPLED: "Онлайн в момент замера",
    DAU: "Активные игроки",
    VISITS: "Сеансы",
}


def utc_stamp(when):
    return when.strftime("%Y-%m-%dT%H:%M:%SZ")


def table_row(cells):
    return "| " + " | ".join(map(str, cells)) + " |"


def number(value, decimals=0):
    if value is None:
        return "—"
    return f"{value:,.{decimals}f}".replace(",", " ").replace(".", ",")


def ad_cells(impressions, clicks, spend):
    ctr = number(100 * clicks / impressions, 2) + "%" if impressions and clicks is not None else "—"
    cpc = spend / clicks if clicks and spend is not None else None
    return [number(impressions), number(clicks), number(spend, 2), ctr, number(cpc, 4)]


def closed_data(metrics, names, cutoff):
    return {
        name: {
            stamp: value for stamp, value in metrics.get(name, {}).items()
            if stamp < cutoff and isinstance(value, (int, float)) and math.isfinite(value)
        }
        for name in names
    }


def correlation_rows(data, targets, start, minimum):
    rows = [
        "| Реклама | Игровая метрика | Пар | r Пирсона |",
        "| --- | --- | ---: | ---: |",
    ]
    for target in targets:
        for metric in AD_METRICS:
            keys = sorted(t for t in data[metric].keys() & data[target].keys() if t >= start)
            count = len(keys)
            if count == 0:
                value = "Нет общих наблюдений"
            elif count < minimum:
                value = f"Мало данных (минимум {minimum})"
            else:
                x = [data[metric][key] for key in keys]
                y = [data[target][key] for key in keys]
                if min(x) == max(x) or min(y) == max(y):
                    value = "Постоянный ряд"
                else:
                    value = number(statistics.correlation(x, y), 3)
            rows.append(table_row([LABELS[metric], LABELS[target], count, value]))
    return rows


def build_report(hourly, daily, now):
    """Report on closed buckets only. Input keys are UTC timestamps ending in Z."""
    if now.utcoffset() is None:
        raise ValueError("now must include a time zone")
    now = now.astimezone(timezone.utc)
    hour_end = now.replace(minute=0, second=0, microsecond=0)
    day_end = hour_end.replace(hour=0)
    last_hour = utc_stamp(hour_end - timedelta(hours=1))
    hour_start = utc_stamp(hour_end - timedelta(days=7))
    day_start = utc_stamp(day_end - timedelta(days=28))
    hours = closed_data(hourly, (*AD_METRICS, PEAK, SAMPLED), utc_stamp(hour_end))
    days = closed_data(daily, (*AD_METRICS, DAU, VISITS), utc_stamp(day_end))
    ad_hours = set(hours[IMPRESSIONS]) & hours[CLICKS].keys() & hours[SPEND].keys()
    latest_ads = max(ad_hours, default=None)

    targets = [PEAK]
    if any(stamp >= hour_start for stamp in hours[SAMPLED]):
        targets.append(SAMPLED)
    header = ["Начало часа, UTC", "Показы", "Клики", "Расход, USD", "CTR", "CPC, USD"]
    header.extend(LABELS[target] for target in targets)
    lines = [
        "# Реклама и посещаемость BrickToads",
        "",
        f"Обновлено {now:%Y-%m-%d %H:%M} UTC. Все интервалы приведены в UTC.",
        "",
        "## Последний завершённый час",
        "",
        table_row(header),
        table_row(["---"] + ["---:"] * (len(header) - 1)),
    ]
    stamps = [last_hour]
    if latest_ads and latest_ads != last_hour:
        stamps.append(latest_ads)
    for stamp in stamps:
        row = [stamp[:16].replace("T", " ")]
        row.extend(ad_cells(*(hours[name].get(stamp) for name in AD_METRICS)))
        row.extend(number(hours[target].get(stamp)) for target in targets)
        lines.append(table_row(row))
    lines.append("")
    if not latest_ads:
        lines.extend(["Пока нет часа, за который Roblox вернул все три рекламные метрики.", ""])
    elif latest_ads != last_hour:
        lines.extend(["Во второй строке приведён последний час со всеми тремя рекламными метриками.", ""])

    last24 = sorted(stamp for stamp in ad_hours if stamp >= utc_stamp(hour_end - timedelta(days=1)))
    lines.append(f"Из последних 24 завершённых часов все три рекламные метрики доступны за {len(last24)}.")
    if last24:
        totals = ad_cells(*(sum(hours[name][stamp] for stamp in last24) for name in AD_METRICS))
        lines.append(
            f"За эти часы суммарно {totals[0]} показов, {totals[1]} кликов, расход {totals[2]} USD."
        )
    lines.extend(["", "## Игровая аналитика за сутки", ""])
    latest_game = max(days[DAU].keys() | days[VISITS].keys(), default=None)
    if latest_game:
        lines.extend([
            "| Дата, UTC | Активные игроки (DAU) | Сеансы |",
            "| --- | ---: | ---: |",
            table_row([
                latest_game[:10], number(days[DAU].get(latest_game)), number(days[VISITS].get(latest_game))
            ]),
        ])
    else:
        lines.append("Данных об активных игроках и сеансах за завершённые дни пока нет.")
    lines.extend([
        "",
        "## Корреляция по часам",
        "",
        "Окно охватывает последние 168 завершённых часов. Для каждой пары показателей нужно не менее 24 общих часов.",
        "",
        *correlation_rows(hours, targets, hour_start, 24),
        "",
        "## Корреляция по дням",
        "",
        "Окно охватывает последние 28 завершённых дней. Для каждой пары показателей нужно не менее 7 общих дней.",
        "",
        *correlation_rows(days, [DAU, VISITS], day_start, 7),
        "",
        "В расчёт входят только интервалы, за которые есть оба значения. "
        "Коэффициент показывает линейную связь. По нему нельзя определить, сколько игроков привлекла реклама.",
    ])
    return "\n".join(lines) + "\n"
