# Roblox Ads Manager API

Русский справочник по HTTP API для рекламы игр Roblox. Версия сервиса `v1`, срез от **19 ноября 2026 года**. Базовый адрес — `https://apis.roblox.com/ads-management/v1`. Он охватывает 22 метода на 17 путях. В конце приведены отдельные адреса для аналитики и смежных сервисов. [Исходная документация Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising)

[Каталог методов](#endpoints) · [Параметры и ответы](#contracts) · [Схемы JSON](#models) · [Примеры для BrickToads](#examples) · [Фактические расходы и показы](#reports) · [Ошибки](#errors) · [Смежные сервисы](#related)

## Подключение

Для скрипта передавайте ключ Open Cloud в заголовке `x-api-key`. Для интеграции от имени пользователя у поддерживаемых методов укажите `Authorization: Bearer <access_token>`. Права действуют в пределах доступа владельца к игре и рекламному счёту. В OpenAPI у четырёх методов биллинга указаны API-ключ и cookie Roblox. Поддержку OAuth смотрите в карточке конкретного метода. Публичный интерфейс рассчитан на внешние приложения: спецификация помечает все 22 операции как недоступные через игровой `HttpService` с API-ключом. [Документация ключей](https://create.roblox.com/docs/cloud/auth/api-keys) · [Области доступа](https://create.roblox.com/docs/cloud/reference/scopes)

| Разрешение | Что можно делать |
|---|---|
| `ad.campaign:read` | Смотреть игры, настройки, кампании, объявления и изображения. Запрашивать прогнозы и рекомендации. |
| `ad.campaign:write` | Проверять и создавать кампании, менять бюджет и статусы, управлять креативами. |
| `ad.billing:read` | Проверять счёт, историю операций и предварительный расчёт обмена Robux. |
| `universe.analytics:read` | Читать фактические рекламные показатели через отдельный Analytics Query API. |

После создания аккаунта настройте оплату в Ads Manager. Список доступных способов оплаты именно для выбранной игры возвращает `GET /campaign-options?universeId=…`. Первичная регистрация счёта и добавление платёжного средства выполняются в портале. [Настройка рекламного счёта](https://create.roblox.com/docs/production/promotion/ads-manager)

### Какой идентификатор передавать

| Поле или путь | Какое значение нужно |
|---|---|
| `universeId`, `targetUniverseId` | Числовой ID игры (Universe ID), представленный строкой. Для BrickToads это `"10777822493"`. Стартовое место той же игры имеет отдельный Place ID `127067245911754`. |
| `billingAccountId`, идентификатор кампании | UUID соответствующего счёта или кампании. |
| `creativeAssetIds[]`, `/creatives/{id}` | Числовой ID изображения Roblox в виде строки, поле `Creative.assetId`. |
| `Creative.id` | UUID регистрации изображения в библиотеке. |
| `/campaigns/{campaignId}/ads/{adId}` | ID конкретного объявления, поле `CampaignAd.id`. В аналитике ему соответствует измерение `AdId`. |

<a id="endpoints"></a>

## Каталог методов

В этом разделе пути отсчитываются от `https://apis.roblox.com/ads-management/v1`. Нажмите на метод, чтобы открыть его параметры, схемы и ответы.

### Доступ и планирование

| Метод и путь | Назначение |
| --- | --- |
| [`GET /advertisable-universes`](#op-listadvertisableuniverses) | Найти игры, доступные для рекламы |
| [`GET /campaign-options`](#op-getcampaignoptions) | Проверить допуск и настройки для игры |
| [`POST /campaign-recommendations`](#op-createcampaignrecommendation) | Подобрать бюджет и срок |
| [`POST /audience-estimates`](#op-createaudienceestimate) | Оценить охват аудитории |
| [`POST /performance-estimates`](#op-createperformanceestimate) | Спрогнозировать результат или бюджет |

### Кампании

| Метод и путь | Назначение |
| --- | --- |
| [`GET /campaigns`](#op-listcampaigns) | Получить список кампаний |
| [`GET /campaigns/{id}`](#op-getcampaign) | Прочитать кампанию и статус показа |
| [`POST /campaigns:validate`](#op-validatecampaign) | Проверить параметры без запуска |
| [`POST /campaigns`](#op-createcampaign) | Создать и запланировать кампанию |
| [`PATCH /campaigns/{id}`](#op-updatecampaign) | Изменить, приостановить или отменить кампанию |
| [`POST /campaigns:batchGetStatus`](#op-batchgetcampaignstatus) | Проверить статусы до 100 кампаний |

### Объявления

| Метод и путь | Назначение |
| --- | --- |
| [`GET /campaigns/{campaignId}/ads`](#op-listcampaignads) | Перечислить объявления кампании |
| [`GET /campaigns/{campaignId}/ads/{adId}`](#op-getcampaignad) | Проверить объявление и результат модерации |
| [`PATCH /campaigns/{campaignId}/ads/{adId}`](#op-updatecampaignad) | Включить или приостановить объявление |

### Библиотека изображений

| Метод и путь | Назначение |
| --- | --- |
| [`GET /creatives`](#op-listcreatives) | Прочитать библиотеку изображений |
| [`POST /creatives`](#op-createcreative) | Зарегистрировать изображение в библиотеке |
| [`GET /creatives/{id}`](#op-getcreative) | Получить изображение по assetId |
| [`PATCH /creatives/{id}`](#op-updatecreative) | Изменить привязку изображения или архивировать его |

### Оплата и история операций

| Метод и путь | Назначение |
| --- | --- |
| [`GET /billing-accounts`](#op-listbillingaccounts) | Найти рекламные счета |
| [`GET /billing-accounts/{id}`](#op-getbillingaccount) | Проверить состояние и способы оплаты счёта |
| [`GET /billing-accounts/{id}/payment-activities`](#op-listpaymentactivities) | Прочитать списания, возвраты и операции с кредитами |
| [`POST /billing-accounts/{id}/ad-credit-conversions:preview`](#op-previewadcreditconversion) | Рассчитать обмен Robux на рекламные кредиты |

<a id="contracts"></a>

## Параметры и ответы

Тела запросов и ответов используют `application/json`. Лимиты в карточках указаны в запросах в минуту на владельца API-ключа или авторизацию OAuth. Пустая или неполная страница с `nextPageToken` означает, что чтение нужно продолжить. Для повторного запроса сохраните исходные фильтры.

<a id="op-listadvertisableuniverses"></a>

### `GET /advertisable-universes`

Возвращает за один запрос Universe ID всех доступных для рекламы игр. Параметр groupId ограничивает результат играми группы. Названия можно получить в Universe API.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListAdvertisableUniverses)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListAdvertisableUniversesResponse](#model-listadvertisableuniversesresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный groupId. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-getcampaignoptions"></a>

### `GET /campaign-options`

С universeId проверяет допуск игры, доступные цели, плательщиков, способы оплаты и таргетинг. Отсутствие права рекламировать игру даёт 403 UNIVERSE_NOT_ADVERTISABLE. Без universeId возвращается общее меню. В таком ответе наличие CREDIT_CARD или ADS_CREDIT не подтверждает готовность счёта к оплате.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#GetCampaignOptions)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `universeId` | query | `string` | нет | Числовой идентификатор игры (Universe ID) строкой. |
| `objective` | query | `string` | нет | Фильтр по цели рекламной кампании. Значения: `PLAYS`, `ENGAGEMENT`, `ROBUX_SPEND`. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [CampaignOptionsResponse](#model-campaignoptionsresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный objective или universeId. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав на запрос или на рекламу этой игры. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-createcampaignrecommendation"></a>

### `POST /campaign-recommendations`

Предлагает дневной бюджет и длительность. Учитывает игру и тип аудитории, включая RETENTION и REACTIVATION. В targeting здесь принимается только audienceType. Возраст, страны, регионы и устройства приводят к 400 UNSUPPORTED_VALUE.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#CreateCampaignRecommendation)

**Тело запроса** [CampaignRecommendationRequest](#model-campaignrecommendationrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [CampaignRecommendationResponse](#model-campaignrecommendationresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-createaudienceestimate"></a>

### `POST /audience-estimates`

Оценивает диапазон потенциального охвата для выбранной аудитории. Принимает все поддерживаемые цели и комбинации таргетинга, доступные при создании кампании, включая регионы. Прогноз не гарантирует показы.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#CreateAudienceEstimate)

**Тело запроса** [AudienceEstimateRequest](#model-audienceestimaterequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [AudienceEstimateResponse](#model-audienceestimateresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-createperformanceestimate"></a>

### `POST /performance-estimates`

Для цели PLAYS оценивает ожидаемый результат по бюджету либо необходимый бюджет для целевого результата. Игру должен иметь право рекламировать вызывающий пользователь. Результат не кэшируется.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#CreatePerformanceEstimate)

**Тело запроса** [PerformanceEstimateRequest](#model-performanceestimaterequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [PerformanceEstimateResponse](#model-performanceestimateresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Ресурс или прогноз недоступен. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |
| `504` | [ErrorEnvelope](#model-errorenvelope) | Истекло время ожидания ответа. |

<a id="op-listcampaigns"></a>

### `GET /campaigns`

Выводит кампании личного счёта, счёта группы по groupId или выбранных игр по targetUniverseIds. При выборке по играм без endedAfter действует окно 730 дней. При выборке по счёту без endedAfter фильтр по дате окончания не задан. Размер страницы по умолчанию 50, максимум 100. Даже у пустой страницы может быть nextPageToken.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 600 для ключа, 600 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListCampaigns)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |
| `targetUniverseIds` | query | массив из `string` | нет | До десяти ID, включая повторы. Повторяйте параметр для каждого ID. Несовместим с groupId. Список через запятую приводит к HTTP 400. |
| `endedAfter` | query | `string` (`date-time`) | нет | Берёт кампании без даты окончания или с окончанием начиная с этого момента. Допустимы последние 730 дней до текущего времени. Без параметра при выборке по играм действует окно 730 дней, при выборке по счёту фильтр даты не задан. |
| `maxPageSize` | query | `integer` | нет | Верхняя граница числа записей на странице. По умолчанию 50. Минимум `1`. Максимум `100`. |
| `pageToken` | query | `string` | нет | Непрозрачный курсор из предыдущего ответа. Сохраняйте фильтры и порядок идентификаторов между страницами. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListCampaignsResponse](#model-listcampaignsresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Проверьте параметры пагинации, дату endedAfter и список игр. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-getcampaign"></a>

### `GET /campaigns/{id}`

Возвращает управляемый status и отдельный deliveryStatus с причинами ожидания, отказа или обучения. Участнику группы с правом рекламировать игру для чтения групповой кампании достаточно её ID. Для отсутствующей или недоступной кампании возвращается 404.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 600 для ключа, 600 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#GetCampaign)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | UUID кампании. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [Campaign](#model-campaign) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный ID кампании. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Кампания недоступна или не найдена. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-validatecampaign"></a>

### `POST /campaigns:validate`

Проверяет параметры, права, допуск и выбор плательщика без создания кампании. HTTP 200 подтверждает выполнение проверки. Прочитайте valid, errors, warnings и resolvedBillingAccountId. Проверка формата idempotencyKey не резервирует ключ.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ValidateCampaign)

**Тело запроса** [CreateCampaignRequest](#model-createcampaignrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ValidateCampaignResponse](#model-validatecampaignresponse) | Проверка выполнена. Итог находится в поле valid. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Тело запроса не удалось разобрать. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Не удалось определить доступный счёт для этой кампании. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-createcampaign"></a>

### `POST /campaigns`

Создаёт оплачиваемую кампанию, проверяет доступ к ассетам и добавляет изображения в библиотеку. После создания возможна модерация или ожидание запланированного старта. Для безопасного повтора передавайте тот же UUID idempotencyKey и то же тело. В течение 24 часов повтор может вернуть исходную кампанию с HTTP 200, даже если тело изменено. При ещё выполняющемся запросе возможен 429.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#CreateCampaign)

**Тело запроса** [CreateCampaignRequest](#model-createcampaignrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [Campaign](#model-campaign) | Создана кампания либо возвращён результат предыдущего создания по тому же ключу идемпотентности. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Ошибка параметров, ассета, задан endTime либо достигнут лимит кампаний. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Нет права управлять счётом, рекламировать игру или использовать ассет. |
| `409` | [ErrorEnvelope](#model-errorenvelope) | Конфликт одновременной записи. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Слишком много запросов либо первоначальное создание с этим ключом ещё выполняется. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-updatecampaign"></a>

### `PATCH /campaigns/{id}`

Изменяет поддерживаемые поля. График можно изменить до старта. Увеличение бюджета применяется сразу, уменьшение у работающей кампании — с ближайшей полуночи счёта. Новые creativeAssetIds добавляются к текущим, повторы игнорируются. Отмену CANCELLED можно повторить, остальные изменения завершённой или отменённой кампании отклоняются. Цель, плательщик, игра, способ оплаты, тип бюджета, таргетинг и ставка фиксируются при создании. Изменение видео зависит от возможностей счёта. Увеличить расходы кампании, оплачиваемой с личного счёта, в том числе возобновить её показ, может только владелец этого счёта. Для автоматического пополнения рекламных кредитов группы требуется право `spendGroupFunds`.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#UpdateCampaign)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | UUID кампании. |

**Тело запроса** [UpdateCampaignRequest](#model-updatecampaignrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [Campaign](#model-campaign) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Ошибка параметров либо попытка изменить постоянное поле. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Кампания недоступна или не найдена. |
| `409` | [ErrorEnvelope](#model-errorenvelope) | Конфликт обновлений, в том числе с незавершённым изменением видео. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-batchgetcampaignstatus"></a>

### `POST /campaigns:batchGetStatus`

Для максимум 100 ID возвращает статус кампании, состояние показов и причины. Ошибки отдельных ID находятся в failures. Недоступные кампании и отсутствующие ID получают одинаковую причину NOT_FOUND.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#BatchGetCampaignStatus)

**Тело запроса** [BatchGetStatusRequest](#model-batchgetstatusrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [BatchGetStatusResponse](#model-batchgetstatusresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Ошибка запроса либо передано больше 100 ID. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-listcampaignads"></a>

### `GET /campaigns/{campaignId}/ads`

Перечисляет объявления кампании от старых к новым, в том числе PAUSED и REMOVED. Каждому изображению соответствует объявление. Поле id совпадает со значением AdId в Analytics Query API.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListCampaignAds)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `campaignId` | path | `string` | да | UUID кампании. |
| `maxPageSize` | query | `integer` | нет | Верхняя граница числа записей на странице. По умолчанию 50. Минимум `1`. Максимум `100`. |
| `pageToken` | query | `string` | нет | Непрозрачный курсор из предыдущего ответа. Сохраняйте фильтры и порядок идентификаторов между страницами. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListCampaignAdsResponse](#model-listcampaignadsresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный размер страницы или курсор. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Кампания недоступна или не найдена. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-getcampaignad"></a>

### `GET /campaigns/{campaignId}/ads/{adId}`

Возвращает объявление внутри указанной кампании. Ошибка 404 возможна при неверной паре campaignId и adId, отсутствии ресурса или недостатке прав.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 600 для ключа, 600 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#GetCampaignAd)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `campaignId` | path | `string` | да | UUID кампании. |
| `adId` | path | `string` | да | Идентификатор объявления внутри выбранной кампании. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [CampaignAd](#model-campaignad) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Недоступна кампания или объявление либо объявление принадлежит другой кампании. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-updatecampaignad"></a>

### `PATCH /campaigns/{campaignId}/ads/{adId}`

Переключает отдельное объявление между ACTIVE и PAUSED. Для объявления в состоянии REMOVED, завершённой или отменённой кампании возвращает 400 FAILED_PRECONDITION.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#UpdateCampaignAd)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `campaignId` | path | `string` | да | UUID кампании. |
| `adId` | path | `string` | да | Идентификатор объявления внутри выбранной кампании. |

**Тело запроса** [UpdateCampaignAdRequest](#model-updatecampaignadrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [CampaignAd](#model-campaignad) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Ошибка параметров либо текущее состояние запрещает изменение. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Недоступна кампания или объявление либо объявление принадлежит другой кампании. |
| `409` | [ErrorEnvelope](#model-errorenvelope) | Конфликт одновременных изменений. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-listcreatives"></a>

### `GET /creatives`

Возвращает зарегистрированные на счёте изображения, данные модерации и размеры. Списки поддерживают фильтры и курсор. Если страница пуста после фильтрации и есть nextPageToken, продолжайте обход. Для операций с изображением нужен assetId.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа, 120 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListCreatives)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |
| `universeId` | query | `string` | нет | Числовой идентификатор игры (Universe ID) строкой. |
| `isArchived` | query | `boolean` | нет | Фильтр по признаку архивации изображения. |
| `assetType` | query | `string` | нет | Фильтр по типу ассета. Значения: `IMAGE`. |
| `maxPageSize` | query | `integer` | нет | Верхняя граница числа записей на странице. По умолчанию 50. Минимум `1`. Максимум `500`. |
| `pageToken` | query | `string` | нет | Непрозрачный курсор из предыдущего ответа. Сохраняйте фильтры и порядок идентификаторов между страницами. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListCreativesResponse](#model-listcreativesresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный размер страницы или курсор. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-createcreative"></a>

### `POST /creatives`

Регистрирует существующее изображение Roblox. Размер и модерацию определяет сервис. Повторная регистрация активного ассета на том же счёте даёт 409 ALREADY_EXISTS даже с другим universeId. Архивная запись восстанавливается с переданными значениями.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#CreateCreative)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |

**Тело запроса** [CreateCreativeRequest](#model-createcreativerequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `201` | [Creative](#model-creative) | Изображение сохранено в библиотеке. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос либо изображение недоступно для использования. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `409` | [ErrorEnvelope](#model-errorenvelope) | Активная запись этого ассета уже есть в библиотеке счёта. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-getcreative"></a>

### `GET /creatives/{id}`

Ищет изображение по десятичному assetId в личном счёте или в счёте группы по groupId. Передача UUID записи библиотеки приводит к 404. Такая же ошибка возникает для неизвестных или недоступных изображений.

**Доступ** `ad.campaign:read` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 600 для ключа, 600 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#GetCreative)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | Числовой Roblox assetId изображения из выбранного счёта. UUID записи библиотеки в этом пути даст 404. |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [Creative](#model-creative) | Успешный запрос. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Изображение не найдено или запись недоступна. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-updatecreative"></a>

### `PATCH /creatives/{id}`

Меняет архивный статус или привязку изображения к игре. Для архивирования передайте только isArchived=true. Активное объявление, использующее изображение, даёт 409. universeId=null отвязывает игру. Пустой объект возвращает текущее состояние. В пути передаётся assetId.

**Доступ** `ad.campaign:write` · API-ключ, OAuth 2.0, cookie Roblox · `BETA`. **Лимит в минуту** 60 для ключа, 60 для OAuth. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#UpdateCreative)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | Числовой Roblox assetId изображения из выбранного счёта. UUID записи библиотеки в этом пути даст 404. |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |

**Тело запроса** [UpdateCreativeRequest](#model-updatecreativerequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [Creative](#model-creative) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Некорректный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Нет разрешения на привязку к новой игре. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Изображение не найдено или запись недоступна. |
| `409` | [ErrorEnvelope](#model-errorenvelope) | Изображение используется включённым объявлением либо обнаружен конфликт изменений. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-listbillingaccounts"></a>

### `GET /billing-accounts`

Перечисляет рекламные счета пользователя или указанной группы вместе с часовым поясом, состоянием оплаты и доступными способами финансирования. Групповой счёт поддерживает ADS_CREDIT. Для привязки к конкретной игре проверьте campaign-options.

**Доступ** `ad.billing:read` · API-ключ, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListBillingAccounts)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `groupId` | query | `string` | нет | Числовой ID группы строкой. Выбирает её рекламный счёт. Без параметра используется личный счёт. |
| `maxPageSize` | query | `integer` | нет | Верхняя граница числа записей на странице. По умолчанию 50. Минимум `1`. Максимум `100`. |
| `pageToken` | query | `string` | нет | Непрозрачный курсор из предыдущего ответа. Сохраняйте фильтры и порядок идентификаторов между страницами. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListBillingAccountsResponse](#model-listbillingaccountsresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Проверьте groupId, размер страницы и курсор. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-getbillingaccount"></a>

### `GET /billing-accounts/{id}`

Возвращает состояние конкретного счёта, сведения о проверке привязанной карты и причину ограничения оплаты. Данные карты маскируются. Ответ 404 одинаков для отсутствующего и недоступного счёта.

**Доступ** `ad.billing:read` · API-ключ, cookie Roblox · `BETA`. **Лимит в минуту** 120 для ключа. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#GetBillingAccount)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | UUID платёжного счёта. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [BillingAccount](#model-billingaccount) | Успешный запрос. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Счёт недоступен или не найден. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-listpaymentactivities"></a>

### `GET /billing-accounts/{id}/payment-activities`

Возвращает один журнал от новых операций к старым. Для CARD укажите CHARGE или REFUND. У CHARGE и AD_CREDIT фильтр может убрать все записи очередной страницы. Если есть nextPageToken, запросите следующую. Для REFUND обязательны startTime включительно и endTime исключительно. Все возвраты выдаются сразу. Если за интервал поступило более 100 запросов на возврат, включая некарточные, сузьте период. Записи без платёжных деталей сохраняются, а известные некарточные платежи исключаются из результата карточного журнала.

**Доступ** `ad.billing:read` · API-ключ, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 120 для ключа. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#ListPaymentActivities)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | UUID платёжного счёта. |
| `ledger` | query | `string` | да | Выберите журнал карты или рекламных кредитов. Значения: `CARD`, `AD_CREDIT`. |
| `type` | query | `string` | нет | Для журнала CARD обязателен выбор CHARGE или REFUND. Для AD_CREDIT параметр не поддерживается. Значения: `CHARGE`, `REFUND`. |
| `startTime` | query | `string` (`date-time`) | нет | Начало интервала возвратов включительно. Обязательно при REFUND, недопустимо в остальных выборках. |
| `endTime` | query | `string` (`date-time`) | нет | Конец интервала возвратов исключительно. Должен быть позже startTime. Обязательно только при REFUND. |
| `maxPageSize` | query | `integer` | нет | Верхняя граница числа записей на странице. По умолчанию 50. Только для CHARGE и AD_CREDIT. Минимум `1`. Максимум `100`. |
| `pageToken` | query | `string` | нет | Непрозрачный курсор из предыдущего ответа. Сохраняйте фильтры и порядок идентификаторов между страницами. Только для CHARGE и AD_CREDIT. |

**Тело запроса** отсутствует.

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [ListPaymentActivitiesResponse](#model-listpaymentactivitiesresponse) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Проверьте журнал, пагинацию и временные границы. При REFUND_WINDOW_TOO_LARGE сократите период. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Счёт недоступен или не найден. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="op-previewadcreditconversion"></a>

### `POST /billing-accounts/{id}/ad-credit-conversions:preview`

Вычисляет, сколько кредитов получится из суммы Robux или сколько Robux потребуется на желаемые кредиты. Учитывает баланс и действующий курс. При недоступной сумме возможен HTTP 200 с valid=false и причиной. Обмена при проверке не происходит.

**Доступ** `ad.billing:read` · API-ключ, cookie Roblox · `EXPERIMENTAL`. **Лимит в минуту** 60 для ключа. [Карточка Roblox](https://create.roblox.com/docs/cloud/reference/features/advertising#PreviewAdCreditConversion)

| Параметр | Где | Тип | Обяз. | Назначение и ограничения |
| --- | --- | --- | --- | --- |
| `id` | path | `string` | да | UUID платёжного счёта. |

**Тело запроса** [PreviewAdCreditConversionRequest](#model-previewadcreditconversionrequest) (обязательно).

| HTTP | Модель ответа | Результат |
| --- | --- | --- |
| `200` | [AdCreditConversionPreview](#model-adcreditconversionpreview) | Успешный запрос. |
| `400` | [ErrorEnvelope](#model-errorenvelope) | Параметры не прошли проверку. |
| `403` | [ErrorEnvelope](#model-errorenvelope) | Недостаточно прав. |
| `404` | [ErrorEnvelope](#model-errorenvelope) | Счёт недоступен или не найден. |
| `429` | [ErrorEnvelope](#model-errorenvelope) | Превышен лимит запросов. |
| `500` | [ErrorEnvelope](#model-errorenvelope) | Внутренняя ошибка сервиса. |

<a id="models"></a>

## Схемы JSON

Схемы расположены по алфавиту. Колонка «Обяз.» воспроизводит список `required` опубликованной схемы. Условные требования зависят от операции и указаны в описаниях. Формат `date-time` соответствует RFC 3339. Строки с ID Roblox и денежными суммами передаются в кавычках.

[AdCreditConversionPreview](#model-adcreditconversionpreview) · [AdCreditConversionTierBreakdown](#model-adcreditconversiontierbreakdown) · [AdFormat](#model-adformat) · [AdvertisableUniverse](#model-advertisableuniverse) · [AudienceEstimateRequest](#model-audienceestimaterequest) · [AudienceEstimateResponse](#model-audienceestimateresponse) · [BatchGetStatusRequest](#model-batchgetstatusrequest) · [BatchGetStatusResponse](#model-batchgetstatusresponse) · [BillingAccount](#model-billingaccount) · [BillingAccountLimits](#model-billingaccountlimits) · [BillingAccountOption](#model-billingaccountoption) · [Budget](#model-budget) · [BudgetConstraint](#model-budgetconstraint) · [Campaign](#model-campaign) · [CampaignAd](#model-campaignad) · [CampaignIDFailure](#model-campaignidfailure) · [CampaignOptionsResponse](#model-campaignoptionsresponse) · [CampaignRecommendationRequest](#model-campaignrecommendationrequest) · [CampaignRecommendationResponse](#model-campaignrecommendationresponse) · [CampaignStatus](#model-campaignstatus) · [CampaignVideo](#model-campaignvideo) · [CreateCampaignRequest](#model-createcampaignrequest) · [CreateCreativeRequest](#model-createcreativerequest) · [Creative](#model-creative) · [CreativeRequirements](#model-creativerequirements) · [Creator](#model-creator) · [ErrorEnvelope](#model-errorenvelope) · [ListAdvertisableUniversesResponse](#model-listadvertisableuniversesresponse) · [ListBillingAccountsResponse](#model-listbillingaccountsresponse) · [ListCampaignAdsResponse](#model-listcampaignadsresponse) · [ListCampaignsResponse](#model-listcampaignsresponse) · [ListCreativesResponse](#model-listcreativesresponse) · [ListPaymentActivitiesResponse](#model-listpaymentactivitiesresponse) · [ObjectiveOption](#model-objectiveoption) · [PaymentActivity](#model-paymentactivity) · [PaymentMethod](#model-paymentmethod) · [PaymentMethodCardBrand](#model-paymentmethodcardbrand) · [PerformanceEstimateBudget](#model-performanceestimatebudget) · [PerformanceEstimateBudgetInput](#model-performanceestimatebudgetinput) · [PerformanceEstimateCampaignContext](#model-performanceestimatecampaigncontext) · [PerformanceEstimateDerivedMetrics](#model-performanceestimatederivedmetrics) · [PerformanceEstimateForecastInput](#model-performanceestimateforecastinput) · [PerformanceEstimateMoneyRange](#model-performanceestimatemoneyrange) · [PerformanceEstimateOutcome](#model-performanceestimateoutcome) · [PerformanceEstimateRequest](#model-performanceestimaterequest) · [PerformanceEstimateResponse](#model-performanceestimateresponse) · [PerformanceEstimateScope](#model-performanceestimatescope) · [PerformanceEstimateTargetOutcome](#model-performanceestimatetargetoutcome) · [PerformanceEstimateValueRange](#model-performanceestimatevaluerange) · [PlanningCampaignContext](#model-planningcampaigncontext) · [PreviewAdCreditConversionRequest](#model-previewadcreditconversionrequest) · [PreviewVideo](#model-previewvideo) · [PublicError](#model-publicerror) · [PublicUniverseEligibility](#model-publicuniverseeligibility) · [Reason](#model-reason) · [Schedule](#model-schedule) · [Targeting](#model-targeting) · [TargetingDimensions](#model-targetingdimensions) · [UpdateBudget](#model-updatebudget) · [UpdateCampaignAdRequest](#model-updatecampaignadrequest) · [UpdateCampaignRequest](#model-updatecampaignrequest) · [UpdateCreativeRequest](#model-updatecreativerequest) · [UpdateSchedule](#model-updateschedule) · [ValidateCampaignResponse](#model-validatecampaignresponse) · [VideoOptions](#model-videooptions)

<a id="model-adcreditconversionpreview"></a>

### `AdCreditConversionPreview`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `adCreditAmountMicros` | `string` | да | Рекламный кредит, который получил бы аккаунт при таком обмене, в миллионных долях USD. |
| `effectiveO18Robux` | `string` | нет | Часть общей суммы из категории Robux для пользователей 18+. Её расходуют первой по повышенному курсу. |
| `effectiveStandardRobux` | `string` | нет | Часть общей суммы, которую пересчитывают по обычному курсу Robux. |
| `reason` | [Reason](#model-reason) | нет | Причина отказа в расчёте. При допустимом обмене поле отсутствует. |
| `robuxAmount` | `string` | да | Число Robux, которое потребовалось бы списать при обмене. |
| `tierBreakdown` | массив из [AdCreditConversionTierBreakdown](#model-adcreditconversiontierbreakdown) | нет | Расчёт по каждому задействованному тарифу в порядке расходования Robux. |
| `valid` | `boolean` | да | Показывает, укладывается ли сумма в допустимый диапазон и хватает ли Robux на балансе. |

<a id="model-adcreditconversiontierbreakdown"></a>

### `AdCreditConversionTierBreakdown`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `adCreditAmountMicros` | `string` | да | Доля рекламного кредита, получаемая по этому тарифу, в миллионных долях USD. |
| `adCreditPerRobux` | `number` (`double`) | да | Сколько долларов рекламного кредита даёт один Robux по этому тарифу. |
| `robuxAmount` | `string` | да | Количество Robux, к которым применяется данный тариф. |
| `tier` | `string` | да | Категория Robux, определяющая курс обмена. Значения: `O18_ELIGIBLE_ROBUX`, `STANDARD_ROBUX`. |

<a id="model-adformat"></a>

### `AdFormat`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `format` | `string` | нет | Вид рекламного материала, например IMAGE. |
| `height` | `integer` | нет | Рекомендуемая высота изображения в пикселях. |
| `width` | `integer` | нет | Рекомендуемая ширина изображения в пикселях. |

<a id="model-advertisableuniverse"></a>

### `AdvertisableUniverse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `universeId` | `string` | да | ID игры, которую пользователь вправе рекламировать. Её название можно запросить через Universe API. |

<a id="model-audienceestimaterequest"></a>

### `AudienceEstimateRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `campaignContext` | [PlanningCampaignContext](#model-planningcampaigncontext) | да | Параметры будущей кампании, для которых оценивается охват. |

<a id="model-audienceestimateresponse"></a>

### `AudienceEstimateResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `lowerBound` | `integer` (`int32`) | да | Нижняя оценка числа пользователей, которых можно охватить. Минимум `0`. |
| `upperBound` | `integer` (`int32`) | да | Верхняя оценка числа пользователей, которых можно охватить. Минимум `0`. |

<a id="model-batchgetstatusrequest"></a>

### `BatchGetStatusRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `campaignIds` | массив из `string` | да | Список ID кампаний для проверки. В одном запросе допускается до 100 ID. Мин. элементов `1`. Макс. элементов `100`. |

<a id="model-batchgetstatusresponse"></a>

### `BatchGetStatusResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `failures` | массив из [CampaignIDFailure](#model-campaignidfailure) | нет | ID, по которым получить статус не удалось. Поле отсутствует, если все кампании найдены. |
| `statuses` | массив из [CampaignStatus](#model-campaignstatus) | нет | Результаты по кампаниям, статусы которых удалось получить. |

<a id="model-billingaccount"></a>

### `BillingAccount`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `adCreditBalanceMicros` | `string` | нет | Доступный остаток рекламного кредита в миллионных долях USD. |
| `createTime` | `string` (`date-time`) | нет | Момент создания рекламного аккаунта в UTC, формат RFC 3339. |
| `creator` | [Creator](#model-creator) | нет | Создатель рекламного аккаунта — пользователь или группа. |
| `displayName` | `string` | нет | Название, под которым рекламный аккаунт виден пользователю. |
| `failedPaymentBalanceMicros` | `string` | нет | Общая сумма неуспешных списаний с карты в миллионных долях USD. |
| `id` | `string` | нет | Идентификатор рекламного аккаунта для подстановки в {id} в методах биллинга. |
| `limits` | [BillingAccountLimits](#model-billingaccountlimits) | нет | Лимиты оплаты картой. Расчёты рекламным кредитом и по выставленному счёту регулируются отдельно. |
| `organizationId` | `string` | нет | ID организации, которой принадлежит рекламный аккаунт. |
| `outstandingBalanceMicros` | `string` | нет | Расходы по карте, ещё не предъявленные к оплате, в миллионных долях USD. |
| `paymentMethods` | массив из [PaymentMethod](#model-paymentmethod) | нет | Сохранённые способы оплаты с частично скрытыми реквизитами. Добавлять и менять карты можно в Ads Manager. |
| `paymentSetupUrl` | `string` (`uri`) | нет | Ссылка на настройку оплаты, покупку кредита или погашение долга в Ads Manager. При READY она справочная. При ACTION_REQUIRED или PAST_DUE по ней можно исправить проблему и затем повторно проверить аккаунт. Поле может отсутствовать, в частности у отключённых аккаунтов. |
| `paymentStatus` | `string` | нет | Готовность к оплате. READY означает, что доступен хотя бы один способ. При ACTION_REQUIRED или DISABLED запустить кампанию нельзя. При PAST_DUE запуск возможен только способом, оставшимся в supportedPaymentTypes. Значения: `READY`, `ACTION_REQUIRED`, `PAST_DUE`, `DISABLED`. |
| `paymentStatusReason` | `string` | нет | Причина состояния оплаты. NO_PAYMENT_METHOD означает отсутствие пригодного источника средств, у группы — нехватку рекламных кредитов. PROFILE_NOT_VERIFIED означает, что требуется проверка карты. Поле относится к состояниям, отличным от READY. Значения: `NO_PAYMENT_METHOD`, `PROFILE_NOT_VERIFIED`, `TRANSACTION_FAILURE`, `ACCOUNT_DISABLED`. |
| `status` | `string` | нет | Состояние самого рекламного аккаунта. Для проверки возможности оплаты служит отдельное поле paymentStatus. Значения: `ACTIVE`, `DISABLED`, `ARCHIVED`. |
| `supportedPaymentTypes` | массив из `string` | нет | Доступные сейчас способы оплаты. Для карты нужны подтверждение и дневной лимит не ниже минимума. Для рекламного кредита нужны активация и остаток не ниже минимума. При создании дополнительно проверяют покрытие дневного бюджета кампании. Группе доступен только рекламный кредит. Значения: `CREDIT_CARD`, `ADS_CREDIT`, `INVOICE`. |
| `timeZone` | `string` | нет | Часовой пояс IANA для дат отчётности и бюджетного расписания, например Europe/Moscow. |
| `type` | `string` | нет | Категория аккаунта. Внешние рекламодатели используют SELF_SERVICE. Категории MANAGED и INTERNAL обслуживает Roblox. Значения: `SELF_SERVICE`, `MANAGED`, `INTERNAL`. |
| `updateTime` | `string` (`date-time`) | нет | Момент последнего изменения рекламного аккаунта в UTC, формат RFC 3339. |

<a id="model-billingaccountlimits"></a>

### `BillingAccountLimits`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `billingThresholdMicros` | `string` | нет | Порог списания накопленных расходов с карты, в миллионных долях USD. Списание происходит, когда outstandingBalanceMicros достигает порога. Поле может появиться до добавления карты и отсутствует, если порог не установлен. Для рекламных кредитов и ежемесячных счетов действуют другие правила. |
| `maximumDailyBudgetMicros` | `string` | нет | Максимальный дневной бюджет при оплате картой, в миллионных долях USD. Для LIFETIME умножьте его на число дней. При значении ≤ 0 положительный бюджет недоступен. Без подтверждённой карты поле отсутствует. Лимит ниже минимального бюджета может отображаться, хотя оплата картой недоступна. На ADS_CREDIT и INVOICE этот лимит не распространяется. |

<a id="model-billingaccountoption"></a>

### `BillingAccountOption`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `creator` | [Creator](#model-creator) | да | Пользователь или группа, создавшие рекламный аккаунт. |
| `displayName` | `string` | да | Отображаемое название рекламного аккаунта. |
| `id` | `string` | да | Значение billingAccountId для кампании, расходы которой оплачивает этот аккаунт. |
| `maximumDailyBudgetMicros` | `string` | нет | Дневной потолок для оплаты картой в миллионных долях USD. Для бюджета LIFETIME потолок умножается на число дней. Без подтверждённой карты поле отсутствует. Значение ниже минимального бюджета не даёт запустить кампанию по карте, значение ≤ 0 исключает положительный бюджет. Не ограничивает ADS_CREDIT и INVOICE. |
| `paymentSetupUrl` | `string` (`uri`) | нет | Ссылка на настройку оплаты, покупку кредита или погашение долга в Ads Manager. Аккаунт со статусом READY уже может платить указанным способом. |
| `paymentStatus` | `string` | нет | Возможность оплатить новую кампанию. Значения интерпретируются так же, как в BillingAccount.paymentStatus. Значения: `READY`, `ACTION_REQUIRED`, `PAST_DUE`, `DISABLED`. |
| `paymentStatusReason` | `string` | нет | Причина проблемы с оплатой, если статус отличается от READY. Для группы NO_PAYMENT_METHOD означает, что не хватает рекламных кредитов. Значения: `NO_PAYMENT_METHOD`, `PROFILE_NOT_VERIFIED`, `TRANSACTION_FAILURE`, `ACCOUNT_DISABLED`. |
| `paymentTypes` | массив из `string` | да | Способы, доступные этому аккаунту сейчас. Карта требует подтверждения и достаточного дневного лимита. Рекламный кредит должен быть активирован и покрывать минимальный дневной бюджет. Группе доступен только ADS_CREDIT, а INVOICE предназначен для управляемого аккаунта. Значения: `CREDIT_CARD`, `ADS_CREDIT`, `INVOICE`. |
| `status` | `string` | да | Состояние рекламного аккаунта. Значения: `ACTIVE`, `DISABLED`, `ARCHIVED`. |
| `type` | `string` | да | Категория рекламного аккаунта. Значения: `SELF_SERVICE`, `MANAGED`, `INTERNAL`. |

<a id="model-budget"></a>

### `Budget`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `amountMicros` | `string` | да | Бюджет в миллионных долях USD. Передавайте целое количество микродолларов строкой. При оплате кредитами дневная сумма должна укладываться в остаток за вычетом невыставленных расходов. Для LIFETIME разделите бюджет на число дней. Лимит карты не применяется к ADS_CREDIT и INVOICE. |
| `scheduledAmountMicros` | `string` | нет | Новый, пониженный бюджет в миллионных долях USD. У работающей кампании он вступает в силу в ближайшую полночь по часовому поясу аккаунта. До этого действует amountMicros. Повышение бюджета применяется сразу. Без отложенного снижения поле отсутствует. Только чтение. |
| `scheduledEffectiveTime` | `string` (`date-time`) | нет | Момент применения запланированного снижения бюджета в UTC, формат RFC 3339. Возвращается только при наличии такого изменения. Только чтение. |
| `type` | `string` | да | Период бюджета — день или весь срок кампании. Выбор фиксируется при создании. Значения: `DAILY`, `LIFETIME`. |

<a id="model-budgetconstraint"></a>

### `BudgetConstraint`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `budgetType` | `string` | да | Период бюджета, к которому относятся эти ограничения. Значения: `DAILY`, `LIFETIME`. |
| `maximumAmountMicros` | `string` | нет | Максимальный дневной бюджет личного аккаунта при оплате картой в миллионных долях USD. Если в запросе есть universeId, лимит берут из записи выбранного аккаунта. Для других способов оплаты это поле отсутствует. |
| `maximumDurationInDays` | `integer` | нет | Наибольшая допустимая длительность кампании в днях. |
| `minimumAmountMicros` | `string` | да | Минимальный бюджет в миллионных долях USD. Для LIFETIME это минимум на каждый день расписания. |

<a id="model-campaign"></a>

### `Campaign`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `autoReloadAdCreditEnabled` | `boolean` | нет | Включено ли автоматическое пополнение рекламного кредита при низком остатке. |
| `billingAccountId` | `string` | нет | Рекламный аккаунт, которому принадлежит кампания и который её оплачивает. |
| `budget` | [Budget](#model-budget) | нет | Сумма, период бюджета и сведения об отложенном снижении, если оно было запланировано. |
| `createTime` | `string` (`date-time`) | нет | Момент создания кампании в UTC, формат RFC 3339. Только чтение. |
| `creativeAssetIds` | массив из `string` | нет | ID рекламных изображений Roblox. Каждый ID соответствует Creative.assetId. |
| `creator` | [Creator](#model-creator) | нет | Пользователь, создавший кампанию. Поле заполняет сервер. Только чтение. |
| `deliveryStatus` | `string` | нет | Фактическое состояние показа, которое определяет Roblox. Доступно для чтения. Значения: `SERVING`, `IN_REVIEW`, `NOT_SERVING`, `REJECTED`. |
| `deliveryStatusReasons` | массив из `string` | нет | Причины текущего состояния, например отказ модерации или обучение системы показа (LEARNING). Если причин нет, поле отсутствует. Значения: `SCHEDULED`, `INSUFFICIENT_AD_CREDIT`, `PAUSED`, `INACTIVE`, `COMPLETED`, `EXPIRED`, `CANCELLED`, `MODERATED`, `CLICK_BAIT`, `GAME_FILTERED`, `PRIVATE`, `PLACE_JOIN_RESTRICTED`, `LEARNING`, `QPP_AUTO_PAUSED`. |
| `id` | `string` | нет | Уникальный ID, который Roblox присвоил кампании. |
| `name` | `string` | нет | Отображаемое название кампании. |
| `objective` | `string` | нет | Цель кампании. При чтении встречаются также цели кампаний, созданных в других интерфейсах. Для создания сверяйтесь с доступными objectiveOptions конкретной игры. Значения: `PLAYS`, `ENGAGEMENT`, `AWARENESS`, `REACH`, `VIDEO_VIEWS`, `ROBUX_SPEND`, `HIGH_VALUE_ACTION`. |
| `paymentType` | `string` | нет | Способ оплаты. Выбирается при создании и впоследствии сохраняется. Значения: `CREDIT_CARD`, `ADS_CREDIT`, `INVOICE`. |
| `schedule` | [Schedule](#model-schedule) | нет | Расписание запуска и продолжительность кампании. |
| `status` | `string` | нет | Состояние, которым управляет рекламодатель через обновление кампании. Отмена CANCELLED окончательна. Значения: `ACTIVE`, `PAUSED`, `CANCELLED`. |
| `targetUniverseId` | `string` | нет | ID игры, которую продвигает кампания. |
| `targeting` | [Targeting](#model-targeting) | нет | Настройки аудитории и сегментации кампании. |
| `updateTime` | `string` (`date-time`) | нет | Момент последнего изменения кампании в UTC, формат RFC 3339. Только чтение. |
| `video` | [CampaignVideo](#model-campaignvideo) | нет | Видеонастройки, общие для всех объявлений кампании. У старых кампаний поле может отсутствовать. |

<a id="model-campaignad"></a>

### `CampaignAd`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `creativeAssetId` | `string` | да | ID изображения Roblox, используемого объявлением. Соответствует Creative.assetId. Только чтение. |
| `deliveryStatus` | `string` | да | Фактическое состояние показа отдельного объявления. Значения: `SERVING`, `IN_REVIEW`, `NOT_SERVING`, `REJECTED`. |
| `id` | `string` | да | Постоянный ID объявления. По нему объявление сопоставляется с измерением AdId в Analytics Query API. Только чтение. |
| `removeTime` | `string` (`date-time`) | нет | Момент удаления в UTC, формат RFC 3339. Заполняется при статусе REMOVED. Только чтение. |
| `reviewIssues` | массив из [Reason](#model-reason) | нет | Выявленные при проверке проблемы с подробностями по каждой из них. |
| `reviewStatus` | `string` | да | Совокупный результат модерации изображения и продвигаемой игры. Значения: `IN_REVIEW`, `APPROVED`, `REJECTED`. |
| `status` | `string` | да | Состояние, заданное для объявления. Оно может быть активно, приостановлено или удалено. Значения: `ACTIVE`, `PAUSED`, `REMOVED`. |

<a id="model-campaignidfailure"></a>

### `CampaignIDFailure`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `id` | `string` | нет | ID кампании, статус которой получить не удалось. |
| `reason` | `string` | нет | Причина ошибки. NOT_FOUND также возвращается, если у вызывающего пользователя нет права управлять этой кампанией. Значения: `NOT_FOUND`. |

<a id="model-campaignoptionsresponse"></a>

### `CampaignOptionsResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `adFormats` | массив из [AdFormat](#model-adformat) | нет | Рекомендуемые размеры изображений для рекламной плитки в пикселях. Изображения других размеров тоже принимаются. |
| `billingAccounts` | массив из [BillingAccountOption](#model-billingaccountoption) | нет | Аккаунты, с которых можно оплатить рекламу игры. Сначала указан личный аккаунт, затем для групповой игры может быть указан аккаунт группы. В запросе создания выбранный ID передают в billingAccountId. |
| `budgetConstraints` | массив из [BudgetConstraint](#model-budgetconstraint) | нет | Минимумы для типов бюджета. Без universeId ответ также может дать дневной лимит личного аккаунта для карты. При указанном universeId смотрите maximumDailyBudgetMicros у выбранного аккаунта. |
| `creativeRequirements` | [CreativeRequirements](#model-creativerequirements) | нет | Допустимые типы рекламных материалов и ограничения на их количество при создании кампании. |
| `eligibility` | [PublicUniverseEligibility](#model-publicuniverseeligibility) | нет | Результат проверки права рекламировать игру. Присутствует только при переданном universeId. |
| `mutableFields` | массив из `string` | нет | Поля, допустимые при обновлении кампании. Значение video появляется, когда видеонастройку разрешено менять. |
| `objectiveOptions` | массив из [ObjectiveOption](#model-objectiveoption) | нет | Доступность каждой цели и поддержка таргетинга. Параметр запроса objective ограничивает результат указанной целью. |
| `objectives` | массив из `string` | нет | Перечень целей API. Доступность каждой цели для выбранной игры проверяется по objectiveOptions. Значения: `PLAYS`, `ENGAGEMENT`, `ROBUX_SPEND`. |
| `paymentTypes` | массив из `string` | нет | При указанном universeId перечислены способы, которыми сейчас может платить хотя бы один из аккаунтов, или пустой список. Без universeId это общий перечень для типа аккаунта, без проверки карты, активации кредита и остатка. Значения: `CREDIT_CARD`, `ADS_CREDIT`, `INVOICE`. |
| `targetingDimensions` | [TargetingDimensions](#model-targetingdimensions) | нет | Допустимые значения параметров аудитории для настройки таргетинга. |
| `video` | [VideoOptions](#model-videooptions) | нет | Возможность использовать видео в рекламной плитке. Возвращается при доступности функции, а для конкретной игры — если её поддерживает хотя бы один из подходящих рекламных аккаунтов. |

<a id="model-campaignrecommendationrequest"></a>

### `CampaignRecommendationRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `campaignContext` | [PlanningCampaignContext](#model-planningcampaigncontext) | да | Игра и категория аудитории targeting.audienceType для расчёта рекомендации. Остальные поля targeting для этого запроса недопустимы. |

<a id="model-campaignrecommendationresponse"></a>

### `CampaignRecommendationResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `budgetOptionsMicros` | массив из `string` | да | Три дневных бюджета в порядке возрастания — ниже рекомендуемого, рекомендуемый и выше. Суммы в миллионных долях USD. |
| `budgetType` | `string` | да | Рекомендации рассчитываются для дневного бюджета. Значения: `DAILY`. |
| `durationOptionsInDays` | массив из `integer` | да | Рекомендуемые варианты длительности в днях по возрастанию. |
| `recommendedBudgetMicros` | `string` | да | Рекомендуемый дневной бюджет в миллионных долях USD. Совпадает с одним из значений budgetOptionsMicros. |

<a id="model-campaignstatus"></a>

### `CampaignStatus`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `deliveryStatus` | `string` | нет | Текущее фактическое состояние показа кампании. Значения: `SERVING`, `IN_REVIEW`, `NOT_SERVING`, `REJECTED`. |
| `deliveryStatusReasons` | массив из `string` | нет | Причины текущего состояния показа. При отсутствии причин поле опускается. Значения: `SCHEDULED`, `INSUFFICIENT_AD_CREDIT`, `PAUSED`, `INACTIVE`, `COMPLETED`, `EXPIRED`, `CANCELLED`, `MODERATED`, `CLICK_BAIT`, `GAME_FILTERED`, `PRIVATE`, `PLACE_JOIN_RESTRICTED`, `LEARNING`, `QPP_AUTO_PAUSED`. |
| `id` | `string` | нет | ID кампании, к которой относится результат. |
| `status` | `string` | нет | Текущее состояние кампании, управляемое рекламодателем. Значения: `ACTIVE`, `PAUSED`, `CANCELLED`. |

<a id="model-campaignvideo"></a>

### `CampaignVideo`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `previewVideoAssetId` | `string` | нет | ID текущего превью-видео игры при выборе PREVIEW_VIDEO. Поле доступно для чтения. Если подходящего видео нет, плитка покажет изображение. ID также отсутствует, если аккаунту недоступны видеоплитки. Только чтение. |
| `source` | `string` | да | Источник содержимого рекламной плитки — изображение или превью-видео игры. Значения: `IMAGE_ONLY`, `PREVIEW_VIDEO`. |

<a id="model-createcampaignrequest"></a>

### `CreateCampaignRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `autoReloadAdCreditEnabled` | `boolean` | нет | Автоматическое пополнение рекламных кредитов при низком остатке. По умолчанию выключено. |
| `billingAccountId` | `string` | нет | UUID счёта плательщика. При отсутствии поля используется личный счёт, в том числе для игры группы. Для оплаты группы выберите её счёт из billingAccounts и игру, принадлежащую этой группе. |
| `budget` | [Budget](#model-budget) | да | Тип бюджета и сумма в миллионных долях USD. |
| `creativeAssetIds` | массив из `string` | да | ID существующих изображений Roblox, доступных владельцу ключа для использования. Указывайте десятичные строки из Creative.assetId. Мин. элементов `1`. Макс. элементов `5`. |
| `idempotencyKey` | `string` (`uuid`) | нет | Необязательный UUID для защиты от повторного создания в течение 24 часов. Пустое или пропущенное значение отключает дедупликацию. Для изменённого тела задавайте новый UUID. Повтор завершённого запроса возвращает прежнюю кампанию с HTTP 200, незавершённого — HTTP 429. |
| `name` | `string` | да | Отображаемое название кампании в Ads Manager. |
| `objective` | `string` | да | Выбирайте доступную цель из objectiveOptions конкретной игры. Для ENGAGEMENT допускается аудитория всех игроков. Значения: `PLAYS`, `ENGAGEMENT`, `ROBUX_SPEND`. |
| `paymentType` | `string` | да | Способ оплаты, доступный выбранному рекламному счёту. Групповой счёт принимает ADS_CREDIT. Значения: `CREDIT_CARD`, `ADS_CREDIT`, `INVOICE`. |
| `schedule` | [Schedule](#model-schedule) | да | Время начала и число дней показа. |
| `targetUniverseId` | `string` | да | Universe ID рекламируемой игры в виде десятичной строки. |
| `targeting` | [Targeting](#model-targeting) | нет | Настройки аудитории. Пропустите поле или передайте пустой объект для всех аудиторий. |
| `video` | [CampaignVideo](#model-campaignvideo) | нет | Настройка видео сразу для всех объявлений. Если поле пропустить, используются только изображения. Доступные источники перечислены в campaign-options в video.sources. |

<a id="model-createcreativerequest"></a>

### `CreateCreativeRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `assetId` | `string` | да | ID изображения Roblox для регистрации в библиотеке рекламного аккаунта. Параметр запроса groupId выбирает аккаунт группы. По умолчанию используется личный аккаунт. |
| `universeId` | `string` | нет | ID игры, с которой следует связать рекламный материал. Связь необязательна. |

<a id="model-creative"></a>

### `Creative`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `assetId` | `string` | нет | ID изображения Roblox для путей GET и PATCH /creatives/{id}. Параметр groupId задаёт групповую библиотеку, по умолчанию используется личная. |
| `assetName` | `string` | нет | Название исходного ресурса Roblox. |
| `assetType` | `string` | нет | Тип медиафайла. В этой версии поддерживаются изображения. Значения: `IMAGE`. |
| `billingAccountId` | `string` | нет | ID рекламного аккаунта, в библиотеке которого находится материал. Только чтение. |
| `createTime` | `string` (`date-time`) | нет | Момент регистрации материала в библиотеке в UTC, формат RFC 3339. |
| `height` | `integer` | нет | Высота изображения в пикселях. Если она неизвестна, поле отсутствует. |
| `id` | `string` (`uuid`) | нет | UUID регистрации материала в библиотеке. Для адресации через GET и PATCH применяется assetId. Только чтение. |
| `isArchived` | `boolean` | нет | Помещён ли материал в архив. Запись остаётся в библиотеке. |
| `moderationStatus` | `string` | нет | Результат или текущее состояние модерации изображения. Значения: `PENDING_REVIEW`, `APPROVED`, `REJECTED`. |
| `source` | `string` | нет | Происхождение изображения — загрузка или генерация средствами Roblox. Значения: `UPLOAD`, `IN_HOUSE_GEN_AI`. |
| `universeId` | `string` | нет | ID связанной игры. У материала без привязки к игре это поле отсутствует. |
| `updateTime` | `string` (`date-time`) | нет | Момент последнего изменения материала в UTC, формат RFC 3339. |
| `width` | `integer` | нет | Ширина изображения в пикселях. Если она неизвестна, поле отсутствует. |

<a id="model-creativerequirements"></a>

### `CreativeRequirements`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `acceptedAssetTypes` | массив из `string` | нет | Типы материалов, допустимые в кампании. Значения: `IMAGE`. |
| `maximumCount` | `integer` | нет | Максимальное количество материалов для одной кампании. |
| `minimumCount` | `integer` | нет | Минимальное количество материалов для одной кампании. |

<a id="model-creator"></a>

### `Creator`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `groupId` | `string` | нет | ID группы-создателя. |
| `userId` | `string` | нет | ID пользователя-создателя. |

<a id="model-errorenvelope"></a>

### `ErrorEnvelope`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `detail` | `string` | да | Текстовое объяснение конкретного сбоя для пользователя. |
| `errors` | массив из [PublicError](#model-publicerror) | да | Список отдельных ошибок. Содержит как минимум один элемент с кодом и сообщением. Мин. элементов `1`. |
| `status` | `integer` | да | Код состояния HTTP, продублированный в теле ответа. |
| `title` | `string` | да | Краткое название категории ошибок. |

<a id="model-listadvertisableuniversesresponse"></a>

### `ListAdvertisableUniversesResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `advertisableUniverses` | массив из [AdvertisableUniverse](#model-advertisableuniverse) | да | Все игры, которые вправе рекламировать вызывающий пользователь в выбранном контексте. Возвращаются одним ответом без постраничной выдачи. |

<a id="model-listbillingaccountsresponse"></a>

### `ListBillingAccountsResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `billingAccounts` | массив из [BillingAccount](#model-billingaccount) | нет | Рекламные аккаунты на текущей странице результата. |
| `nextPageToken` | `string` | нет | Курсор следующей страницы для параметра pageToken. На последней странице поле отсутствует. |

<a id="model-listcampaignadsresponse"></a>

### `ListCampaignAdsResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `ads` | массив из [CampaignAd](#model-campaignad) | да | Объявления кампании на текущей странице. |
| `nextPageToken` | `string` | нет | Курсор следующей страницы для параметра pageToken. На последней странице поле отсутствует. |

<a id="model-listcampaignsresponse"></a>

### `ListCampaignsResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `campaigns` | массив из [Campaign](#model-campaign) | нет | Кампании на текущей странице. |
| `nextPageToken` | `string` | нет | Курсор следующей страницы для параметра pageToken. На последней странице поле отсутствует. |

<a id="model-listcreativesresponse"></a>

### `ListCreativesResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `creatives` | массив из [Creative](#model-creative) | нет | Рекламные материалы на текущей странице. |
| `nextPageToken` | `string` | нет | Курсор следующей страницы для параметра pageToken. На последней странице поле отсутствует. |

<a id="model-listpaymentactivitiesresponse"></a>

### `ListPaymentActivitiesResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `activities` | массив из [PaymentActivity](#model-paymentactivity) | да | Платёжные операции выбранной категории. Для REFUND ответ охватывает весь запрошенный период. |
| `nextPageToken` | `string` | нет | Курсор для следующей страницы списаний CHARGE или операций AD_CREDIT. Отсутствует на последней странице и при выборке REFUND. |

<a id="model-objectiveoption"></a>

### `ObjectiveOption`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `audienceTypes` | массив из `string` | да | Допустимые значения `targeting.audienceType`. Для `ENGAGEMENT` доступно только `ALL_PLAYERS`. Значения: `ALL_PLAYERS`, `NEW_USERS`, `RETENTION`, `REACTIVATION`. |
| `available` | `boolean` | да | Можно ли сейчас использовать цель для этой игры. |
| `objective` | `string` | да | Цель, к которой относятся параметры и ограничения. Значения: `PLAYS`, `ENGAGEMENT`, `ROBUX_SPEND`. |
| `supportsTargeting` | `boolean` | да | Можно ли задать ограничения аудитории при создании кампании. Для `ENGAGEMENT` значение равно `false`. |
| `unavailableReasons` | массив из [Reason](#model-reason) | нет | Причины недоступности цели. Поле появляется при `available: false`. |

<a id="model-paymentactivity"></a>

### `PaymentActivity`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `actorUserId` | `string` | нет | Пользователь Roblox, инициировавший операцию с рекламными кредитами. Появляется при наличии данных для личных и групповых счетов. |
| `adCreditTransactionType` | `string` | нет | Вид исходной операции с рекламными кредитами. Более общая категория указана в `type`. Значения: `DEPOSIT`, `AUTO_DEPOSIT`, `DEBIT`, `REFUND`, `ADJUSTMENT`, `PROMOTION`. |
| `amountMicros` | `string` | да | Сумма фактического списания, возврата, начисления или расхода в миллионных долях доллара США. |
| `campaignId` | `string` | нет | Идентификатор связанной кампании, если операция относится к кампании. |
| `campaignName` | `string` | нет | Название связанной кампании. Передаётся вместе с `campaignId`. |
| `cardLastFourDigits` | `string` | нет | Последние четыре цифры карты. Применимо к `CHARGE` и `REFUND`. |
| `chargeTime` | `string` (`date-time`) | нет | Время последнего расчёта по связанному списанию с карты в формате RFC 3339 UTC. Появляется у `CHARGE`, когда время известно. |
| `createTime` | `string` (`date-time`) | да | Время создания записи в формате RFC 3339 UTC. |
| `currencyCode` | `string` | нет | Валюта карточной операции по ISO 4217. Применимо к `CHARGE` и `REFUND`. |
| `description` | `string` | нет | Текстовое описание операции, если оно доступно. |
| `id` | `string` | нет | Постоянный идентификатор платежа. Появляется, если платежу присвоен идентификатор. |
| `o18RobuxAmount` | `string` | нет | Часть суммы `robuxAmount`, списанная из Robux категории 18+. Применимо к `ROBUX_CONVERSION`. |
| `requestAmountMicros` | `string` | нет | Изначально запрошенная сумма списания или возврата в миллионных долях доллара США. Применимо к `CHARGE` и `REFUND`. |
| `robuxAmount` | `string` | нет | Общее число списанных Robux. Применимо к `ROBUX_CONVERSION`. |
| `state` | `string` | да | Состояние расчётов по операции. Значения: `PENDING`, `SUCCEEDED`, `FAILED`, `REVERSED`. |
| `type` | `string` | да | Вид финансовой операции. Значения: `CHARGE`, `REFUND`, `AD_CREDIT_GRANT`, `AD_CREDIT_SPEND`, `ROBUX_CONVERSION`. |

<a id="model-paymentmethod"></a>

### `PaymentMethod`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `cardBrand` | [PaymentMethodCardBrand](#model-paymentmethodcardbrand) | нет | Платёжная система карты. Для нераспознанной системы возвращается `OTHER`. Значения: `VISA`, `MASTERCARD`, `AMEX`, `DISCOVER`, `JCB`, `DINERS`, `UNIONPAY`, `OTHER`. |
| `displayLabel` | `string` | да | Название для отображения с замаскированным номером, например `Visa …4242`. |
| `expirationMonth` | `integer` | нет | Месяц окончания срока действия карты, от 1 до 12. |
| `expirationYear` | `integer` | нет | Год окончания срока действия карты, четыре цифры. |
| `id` | `string` | да | Идентификатор способа оплаты. |
| `lastFourDigits` | `string` | нет | Последние четыре цифры номера карты. |
| `status` | `string` | да | Текущее состояние способа оплаты. Значения: `ACTIVE`, `ACTION_REQUIRED`, `EXPIRED`, `DISABLED`. |
| `type` | `string` | да | Категория способа оплаты. Значения: `CARD`, `INVOICE`. |
| `verificationState` | `string` | нет | Результат проверки карты. Срок действия учитывается отдельно. Значения: `VERIFIED`, `UNVERIFIED`, `CHALLENGE_PENDING`. |

<a id="model-paymentmethodcardbrand"></a>

### `PaymentMethodCardBrand`

Тип `string`. Значения: `VISA`, `MASTERCARD`, `AMEX`, `DISCOVER`, `JCB`, `DINERS`, `UNIONPAY`, `OTHER`.

<a id="model-performanceestimatebudget"></a>

### `PerformanceEstimateBudget`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `dailyAmountMicroUsd` | `string` | нет | Бюджет на день в миллионных долях доллара США. |
| `dailyAmountMicroUsdRange` | [PerformanceEstimateMoneyRange](#model-performanceestimatemoneyrange) | нет | Диапазон оценки дневного бюджета, если доступен. |
| `lifetimeAmountMicroUsd` | `string` | нет | Бюджет на весь срок кампании в миллионных долях доллара США. Возвращается для бюджета на весь срок. |
| `lifetimeAmountMicroUsdRange` | [PerformanceEstimateMoneyRange](#model-performanceestimatemoneyrange) | нет | Диапазон оценки бюджета на весь срок, если доступен. Для дневного бюджета поле опускается. |

<a id="model-performanceestimatebudgetinput"></a>

### `PerformanceEstimateBudgetInput`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `amountMicroUsd` | `string` | нет | Дневная сумма или сумма на весь срок согласно `forecastScope.budgetType`, в миллионных долях доллара США. |

<a id="model-performanceestimatecampaigncontext"></a>

### `PerformanceEstimateCampaignContext`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `objective` | `string` | да | Цель прогноза. Поддерживается только `PLAYS`. Значения: `PLAYS`. |
| `targetUniverseId` | `string` | да | Идентификатор вселенной игры, для которой рассчитывается прогноз. |

<a id="model-performanceestimatederivedmetrics"></a>

### `PerformanceEstimateDerivedMetrics`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `costPerOutcomeMicroUsd` | `string` | нет | Стоимость одного результата в миллионных долях доллара США. |
| `costPerOutcomeMicroUsdRange` | [PerformanceEstimateMoneyRange](#model-performanceestimatemoneyrange) | нет | Диапазон оценки стоимости одного результата, если доступен. |

<a id="model-performanceestimateforecastinput"></a>

### `PerformanceEstimateForecastInput`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `budget` | [PerformanceEstimateBudgetInput](#model-performanceestimatebudgetinput) | нет | Бюджет, по которому нужно рассчитать ожидаемый результат. |
| `targetOutcome` | [PerformanceEstimateTargetOutcome](#model-performanceestimatetargetoutcome) | нет | Желаемый результат, по которому нужно рассчитать необходимый бюджет. |

<a id="model-performanceestimatemoneyrange"></a>

### `PerformanceEstimateMoneyRange`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `lowerBound` | `string` | нет | Нижняя граница суммы включительно, в миллионных долях доллара США. |
| `upperBound` | `string` | нет | Верхняя граница суммы включительно, в миллионных долях доллара США. |

<a id="model-performanceestimateoutcome"></a>

### `PerformanceEstimateOutcome`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `dailyValue` | `integer` | нет | Ожидаемое число результатов за день. |
| `dailyValueRange` | [PerformanceEstimateValueRange](#model-performanceestimatevaluerange) | нет | Диапазон числа результатов за день, если доступен. |
| `lifetimeValue` | `integer` | нет | Ожидаемое число результатов за весь срок. При дневном бюджете поле опускается. |
| `lifetimeValueRange` | [PerformanceEstimateValueRange](#model-performanceestimatevaluerange) | нет | Диапазон числа результатов за весь срок, если доступен. При дневном бюджете поле опускается. |
| `outcomeType` | `string` | нет | Единица результата в прогнозе. Всегда `PLAYS`. Значения: `PLAYS`. |

<a id="model-performanceestimaterequest"></a>

### `PerformanceEstimateRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `campaignContext` | [PerformanceEstimateCampaignContext](#model-performanceestimatecampaigncontext) | да | Игра и цель, для которых нужен прогноз. |
| `forecastInput` | [PerformanceEstimateForecastInput](#model-performanceestimateforecastinput) | да | Известный бюджет или желаемое число результатов. |
| `forecastScope` | [PerformanceEstimateScope](#model-performanceestimatescope) | да | Тип бюджета и длительность периода, охваченного прогнозом. |

<a id="model-performanceestimateresponse"></a>

### `PerformanceEstimateResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `budget` | [PerformanceEstimateBudget](#model-performanceestimatebudget) | нет | Сумма бюджета, использованная или рассчитанная при прогнозе. |
| `derivedMetrics` | [PerformanceEstimateDerivedMetrics](#model-performanceestimatederivedmetrics) | нет | Расчётные показатели стоимости результата. |
| `outcome` | [PerformanceEstimateOutcome](#model-performanceestimateoutcome) | нет | Результат, использованный или рассчитанный при прогнозе. |
| `predicted` | `string` | нет | Что рассчитал сервис. Значение `OUTCOME` означает прогноз по бюджету, `BUDGET` — бюджет для заданного результата. Значения: `OUTCOME`, `BUDGET`. |

<a id="model-performanceestimatescope"></a>

### `PerformanceEstimateScope`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `budgetType` | `string` | да | Период бюджета в прогнозе. Значения: `DAILY`, `LIFETIME`. |
| `durationInDays` | `integer` | нет | Для `LIFETIME` обязательно положительное число дней. Для `DAILY` значение должно равняться нулю. |

<a id="model-performanceestimatetargetoutcome"></a>

### `PerformanceEstimateTargetOutcome`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `outcomeType` | `string` | нет | Какой результат нужно получить. Поддерживается только `PLAYS`. Значения: `PLAYS`. |
| `value` | `integer` | нет | Желаемое число результатов за день или за весь срок согласно `forecastScope.budgetType`. |

<a id="model-performanceestimatevaluerange"></a>

### `PerformanceEstimateValueRange`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `lowerBound` | `integer` | нет | Нижняя граница количества, включительно. |
| `upperBound` | `integer` | нет | Верхняя граница количества, включительно. |

<a id="model-planningcampaigncontext"></a>

### `PlanningCampaignContext`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `objective` | `string` | да | Цель планируемой рекламы. Значения: `PLAYS`, `ENGAGEMENT`, `ROBUX_SPEND`. |
| `targetUniverseId` | `string` | да | Идентификатор вселенной игры, для которой планируется кампания. |
| `targeting` | [Targeting](#model-targeting) | нет | Предлагаемые настройки аудитории. Для `audience-estimates` действуют правила создания кампании. Для `campaign-recommendations` допускается только `audienceType`. |

<a id="model-previewadcreditconversionrequest"></a>

### `PreviewAdCreditConversionRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `adCreditAmountMicros` | `string` | нет | Желаемая сумма рекламных кредитов в миллионных долях доллара, с точностью не выше одного цента. Ответ содержит стоимость в Robux. |
| `robuxAmount` | `string` | нет | Сколько Robux предполагается потратить. Ответ содержит сумму приобретаемых рекламных кредитов. |

<a id="model-previewvideo"></a>

### `PreviewVideo`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `available` | `boolean` | да | Есть ли у игры предварительное видео, пригодное для показа. |
| `videoAssetId` | `string` | нет | Идентификатор ресурса видео. Возвращается при `available: true`. |

<a id="model-publicerror"></a>

### `PublicError`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `actionUrl` | `string` (`uri`) | нет | Страница Ads Manager, на которой пользователь может устранить причину ошибки. После его действий повторите проверку. Платёжные данные вводятся на стороне Roblox. |
| `code` | `string` | да | Стабильный код категории ошибки для программной обработки. |
| `field` | `string` | нет | Путь к полю запроса, вызвавшему ошибку, если ошибка связана с конкретным полем. |
| `message` | `string` | да | Описание ошибки для пользователя. |
| `reason` | `string` | нет | Более точный программный код причины, если он предусмотрен. |
| `remediation` | `string` | нет | Действия для устранения ошибки. |
| `retryable` | `boolean` | нет | Стоит ли клиенту повторить запрос. |

<a id="model-publicuniverseeligibility"></a>

### `PublicUniverseEligibility`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `details` | массив из [Reason](#model-reason) | нет | Подробности и способы устранения ограничений, по одному элементу на каждую причину из `reasons`. |
| `eligible` | `boolean` | нет | Может ли рекламный аккаунт сейчас рекламировать эту игру. |
| `reasons` | массив из `string` | нет | Причины запрета. У допущенной игры поле отсутствует. `OBJECTIVE_NOT_SUPPORTED` возможно только для запроса с параметром `objective`, если выбранная цель недоступна игре. Значения: `NO_PERMISSION`, `BLOCKED`, `OBJECTIVE_NOT_SUPPORTED`. |
| `universeId` | `string` | нет | Идентификатор проверенной вселенной Roblox. |

<a id="model-reason"></a>

### `Reason`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `code` | `string` | да | Стабильный код причины для программной обработки. |
| `message` | `string` | да | Пояснение причины для пользователя. |
| `remediation` | `string` | нет | Действия, которые могут устранить причину. |
| `resource` | `string` | нет | Ссылка на связанный ресурс в формате API, например `billing-accounts/{id}`. |

<a id="model-schedule"></a>

### `Schedule`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `durationInDays` | `integer` | да | Длительность от даты старта, максимум 3650 дней. Ноль задаёт бессрочную кампанию до паузы или отмены, без `endTime`. Для бюджета `LIFETIME` нужно положительное число. Минимум `0`. Максимум `3650`. |
| `endTime` | `string` (`date-time`) | нет | Вычисленное время завершения в формате RFC 3339 UTC. Соответствует секунде перед полуночью последнего дня по часовому поясу рекламного счёта. Передача в запросе вызывает HTTP 400. Для настройки используйте `durationInDays`. Только чтение. |
| `startTime` | `string` (`date-time`) | да | Запланированное начало показов в формате RFC 3339. Рекомендуется UTC с суффиксом `Z`. При создании время должно быть текущим или будущим. |

<a id="model-targeting"></a>

### `Targeting`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `ageGroups` | массив из `string` | нет | Возрастные группы аудитории. Пустой массив включает все доступные группы. Значения: `AGE_13_17`, `AGE_18_24`, `AGE_25_PLUS`. |
| `audienceType` | `string` | нет | По умолчанию и при `ALL_PLAYERS` охватывает всех игроков. Иные значения выбирают соответствующую аудиторию рекламируемой игры. Для `ENGAGEMENT` можно опустить поле или передать только `ALL_PLAYERS`. Остальные поля таргетинга для этой цели вызывают ошибку. Ответ включает итоговое значение. Значения: `ALL_PLAYERS`, `NEW_USERS`, `RETENTION`, `REACTIVATION`. По умолчанию `ALL_PLAYERS`. |
| `countries` | массив из `string` | нет | Отдельные страны по ISO 3166-1 alpha-2, например `US`. Пустой массив не вводит ограничения по странам. Страну нельзя совмещать с регионом, в который она входит, или с `ALL`. |
| `devices` | массив из `string` | нет | Типы устройств аудитории. Пустой массив включает все доступные устройства. Значения: `PHONE`, `TABLET`, `DESKTOP`, `CONSOLE`. |
| `regions` | массив из `string` | нет | Географические регионы из `targetingDimensions.regions` в ответе `campaign-options`. Пустой массив не вводит ограничения по регионам. Значение `ALL` можно указать только отдельно от других регионов и стран. Значения: `ALL`, `WESTERN_EUROPE`, `EASTERN_EUROPE`, `EAST_ASIA`, `SOUTHEAST_ASIA`, `MIDDLE_EAST`, `LATIN_AMERICA`, `AFRICA`, `ANZ`, `ROW`, `UAC`. |

<a id="model-targetingdimensions"></a>

### `TargetingDimensions`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `ageGroups` | массив из `string` | нет | Возрастные группы, доступные при настройке аудитории. Значения: `AGE_13_17`, `AGE_18_24`, `AGE_25_PLUS`. |
| `countries` | массив из `string` | нет | Доступные коды отдельных стран по ISO 3166-1 alpha-2. |
| `devices` | массив из `string` | нет | Типы устройств, доступные при настройке аудитории. Значения: `PHONE`, `TABLET`, `DESKTOP`, `CONSOLE`. |
| `regions` | массив из `string` | нет | Допустимые общие регионы и значение `ALL`. Для отдельной страны используйте `countries`. Значения: `ALL`, `WESTERN_EUROPE`, `EASTERN_EUROPE`, `EAST_ASIA`, `SOUTHEAST_ASIA`, `MIDDLE_EAST`, `LATIN_AMERICA`, `AFRICA`, `ANZ`, `ROW`, `UAC`. |

<a id="model-updatebudget"></a>

### `UpdateBudget`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `amountMicros` | `string` | да | Новая сумма бюджета в миллионных долях доллара США, десятичной строкой. Для `ADS_CREDIT` учитывается доступный остаток с вычетом ещё не выставленных к оплате расходов. Лимит `maximumDailyBudgetMicros` не применяется к `ADS_CREDIT` и `INVOICE`. |

<a id="model-updatecampaignadrequest"></a>

### `UpdateCampaignAdRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `status` | `string` | да | Желаемое состояние объявления. `ACTIVE` включает его, `PAUSED` приостанавливает. Значения: `ACTIVE`, `PAUSED`. |

<a id="model-updatecampaignrequest"></a>

### `UpdateCampaignRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `autoReloadAdCreditEnabled` | `boolean` | нет | Включает или отключает автоматическое пополнение рекламных кредитов. |
| `budget` | [UpdateBudget](#model-updatebudget) | нет | Изменение суммы бюджета. Тип фиксируется при создании, и передача `type` при обновлении вызывает HTTP 400. |
| `creativeAssetIds` | массив из `string` | нет | Идентификаторы ресурсов Roblox для добавления в кампанию, соответствующие `Creative.assetId`. Уже добавленные ресурсы пропускаются. Макс. элементов `5`. |
| `name` | `string` | нет | Новое отображаемое название кампании. |
| `schedule` | [UpdateSchedule](#model-updateschedule) | нет | Частичное изменение расписания. Допускается до начала кампании. |
| `status` | `string` | нет | Значение `ACTIVE` запускает или возобновляет кампанию, `PAUSED` приостанавливает, `CANCELLED` отменяет окончательно. Значения: `ACTIVE`, `PAUSED`, `CANCELLED`. |
| `targeting` | [Targeting](#model-targeting) | нет | Настройки аудитории фиксируются при создании. Передача этого поля в PATCH вызывает HTTP 400. |
| `video` | [CampaignVideo](#model-campaignvideo) | нет | Новая настройка видео применяется ко всем объявлениям до возврата ответа. Источники перечислены в `video.sources` ответа `campaign-options`. |

<a id="model-updatecreativerequest"></a>

### `UpdateCreativeRequest`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `isArchived` | `boolean` | нет | Перевод материала в архив или восстановление из архива. При архивации передайте только это поле. Ресурс не должен использоваться ни в одном включённом объявлении. |
| `universeId` | `string` | нет | Идентификатор связанной игры. Передайте `null` для удаления связи или опустите поле для её сохранения. Допускает `null`. |

<a id="model-updateschedule"></a>

### `UpdateSchedule`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `durationInDays` | `integer` | нет | Новая длительность кампании от `startTime`. Ноль задаёт кампанию без даты завершения. Минимум `0`. Максимум `3650`. |
| `endTime` | `string` (`date-time`) | нет | Время завершения вычисляется сервером. Если включить поле в запрос, сервис вернёт ошибку. Только чтение. |
| `startTime` | `string` (`date-time`) | нет | Новое время старта в формате RFC 3339. Рекомендуется UTC с суффиксом `Z`. |

<a id="model-validatecampaignresponse"></a>

### `ValidateCampaignResponse`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `errors` | массив из [PublicError](#model-publicerror) | да | Ошибки, которые вернуло бы создание той же кампании, в том же порядке. При успешной проверке массив пуст. |
| `resolvedBillingAccountId` | `string` | нет | Идентификатор рекламного счёта, на котором была бы создана кампания. |
| `valid` | `boolean` | да | Принял бы сервис создания кампании переданные параметры. |
| `warnings` | массив из [Reason](#model-reason) | да | Замечания, которые не препятствуют созданию кампании. |

<a id="model-videooptions"></a>

### `VideoOptions`

| Поле | Тип JSON | Обяз. | Назначение и допустимые значения |
| --- | --- | --- | --- |
| `previewVideo` | [PreviewVideo](#model-previewvideo) | нет | Доступность предварительного видео игры. Поле появляется при запросе с `universeId`. |
| `sources` | массив из `string` | да | Допустимые источники для `CampaignVideo.source`. Значения: `IMAGE_ONLY`, `PREVIEW_VIDEO`. |

<a id="examples"></a>

## Примеры для BrickToads

Ниже используется PowerShell и ключ в переменной окружения текущего процесса `ROBLOX_API_KEY`. Подставляйте ключ через среду выполнения. Примеры не содержат секретов.

### Проверить условия и изображения

```powershell
$base = 'https://apis.roblox.com/ads-management/v1'
$headers = @{ 'x-api-key' = $env:ROBLOX_API_KEY }
$universeId = '10777822493'

$options = Invoke-RestMethod -Headers $headers -Uri "$base/campaign-options?universeId=$universeId"
$options.eligibility
$options.objectiveOptions | Select-Object objective, available
$options.billingAccounts | Select-Object displayName, id, paymentStatus, paymentTypes
$options.budgetConstraints

$library = Invoke-RestMethod -Headers $headers -Uri "$base/creatives?universeId=$universeId&isArchived=false"
$library.creatives | Select-Object assetId, assetName, moderationStatus
```

### Проверить однодневный вариант без запуска

Этот пример берёт минимум дневного бюджета из текущего ответа Roblox. Для него выбран личный счёт с готовой оплатой картой и цель `PLAYS`. Начало вычисляется на момент выполнения. В предыдущей проверке BrickToads 19 ноября 2026 года минимум составлял 0,95 USD. Roblox также принял вариант `ENGAGEMENT` и показал недоступность `ROBUX_SPEND` для этой игры. Эти условия могут измениться.

```powershell
$account = $options.billingAccounts | Where-Object {
    $_.paymentStatus -eq 'READY' -and
    $_.creator.userId -and
    $_.paymentTypes -contains 'CREDIT_CARD'
} | Select-Object -First 1
$daily = $options.budgetConstraints | Where-Object budgetType -eq 'DAILY' | Select-Object -First 1
$plays = $options.objectiveOptions | Where-Object { $_.objective -eq 'PLAYS' -and $_.available }
if (-not ($options.eligibility.eligible -and $account -and $daily -and $plays)) {
    throw 'Проверьте допуск игры, доступность PLAYS, дневной бюджет и способ оплаты.'
}

$body = @{
    name             = 'BrickToads — проверка'
    targetUniverseId = $universeId
    billingAccountId = $account.id
    objective        = 'PLAYS'
    paymentType      = 'CREDIT_CARD'
    creativeAssetIds = @('128788912237244', '82851978294806', '98969728330158', '97892669433968')
    budget           = @{ type = 'DAILY'; amountMicros = [string]$daily.minimumAmountMicros }
    schedule         = @{
        startTime      = [DateTime]::UtcNow.AddDays(1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
        durationInDays = 1
    }
}
$result = Invoke-RestMethod -Method Post -Uri "$base/campaigns:validate" -Headers $headers `
    -ContentType 'application/json; charset=utf-8' -Body ($body | ConvertTo-Json -Depth 8)
$result | Select-Object valid, errors, warnings, resolvedBillingAccountId
```

При успешной проверке результат содержит `valid: true`. Вызов `POST /campaigns` с такими параметрами уже создаёт оплачиваемую кампанию. Для повторяемого создания добавьте в тело новый UUID в `idempotencyKey` и сохраните вместе с неизменённым JSON до завершения запроса.

### Прочитать состояние или приостановить показ

| Действие | Метод | Тело JSON |
|---|---|---|
| Получить статус группы кампаний | `POST /campaigns:batchGetStatus` | `{"campaignIds":["<campaign-uuid>"]}` |
| Приостановить кампанию | `PATCH /campaigns/{id}` | `{"status":"PAUSED"}` |
| Приостановить одно объявление | `PATCH /campaigns/{campaignId}/ads/{adId}` | `{"status":"PAUSED"}` |
| Задать бюджет 5 USD для существующего типа бюджета | `PATCH /campaigns/{id}` | `{"budget":{"amountMicros":"5000000"}}` |

Замените значения в угловых скобках своими идентификаторами. Вызовы `PATCH` применяют изменения к действующей кампании.

## От выбора игры до показов

1. Найдите игру через `GET /advertisable-universes`. Для проверки используйте её **Universe ID**. Запрос `GET /campaign-options?universeId=…` возвращает допуск, доступные цели, плательщиков, минимальный бюджет и требования к изображениям. Ответ `403 UNIVERSE_NOT_ADVERTISABLE` означает, что с этими правами рекламировать выбранную игру нельзя. [Планирование кампании](https://create.roblox.com/docs/cloud/guides/advertising#plan-a-campaign)
2. Выберите цель из `objectiveOptions` с `available=true`. Для настройки аудитории используйте допустимые значения из ответа. Укажите `billingAccountId` нужного плательщика. Для групповой игры без явного выбора может использоваться личный счёт. Групповой счёт оплачивает рекламу своей игры рекламными кредитами. [Счета групп](https://create.roblox.com/docs/cloud/guides/advertising#advertise-a-groups-experience)
3. Передайте в `creativeAssetIds` идентификаторы изображений Roblox (`assetId`). Этот же числовой ID используется в пути `/creatives/{id}`. UUID записи библиотеки и ID объявления — отдельные идентификаторы. Новые файлы загружаются через Assets API. Доступный обработанный ассет можно использовать до регистрации в библиотеке. [Подготовка изображений](https://create.roblox.com/docs/cloud/guides/advertising#prepare-creatives)
4. Отправьте параметры в `POST /campaigns:validate`. Проверка требует `ad.campaign:write`, не создаёт кампанию и не расходует деньги. HTTP 200 означает успешное выполнение проверки. Её результат содержится в `valid`, `errors` и `warnings`. Для запуска служит отдельный `POST /campaigns`. [Проверка и создание](https://create.roblox.com/docs/cloud/guides/advertising)
5. Для создания задайте `idempotencyKey` в теле запроса. Используйте один UUID при повторе того же тела после сетевого сбоя. Для другого тела или новой кампании нужен новый UUID. В течение 24 часов повтор с использованным ключом может вернуть первоначальную кампанию, даже если поля изменились. [Повторные запросы](https://create.roblox.com/docs/cloud/guides/advertising#use-a-new-idempotency-key-for-each-new-request-body)

### Бюджет и статус показа

`amountMicros` — десятичная строка в миллионных долях USD. Например, `"950000"` означает 0,95 USD. Минимум берётся из `budgetConstraints` для выбранной игры. При бюджете `LIFETIME` минимальная сумма за весь срок зависит от числа дней. Для дневного бюджета по карте действует предел `maximumDailyBudgetMicros`. Регистрация рекламного счёта, добавление карты и покупка кредитов доступны в портале. [Оплата в Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager) · [Проверка платёжного счёта](https://create.roblox.com/docs/cloud/guides/advertising#check-that-the-billing-account-can-pay)

`status` показывает решение рекламодателя. Кампанию можно приостановить через `PAUSED`, возобновить через `ACTIVE` и окончательно отменить через `CANCELLED`. За фактический показ отвечает `deliveryStatus`. Причину ожидания, остановки или отклонения ищите в `deliveryStatusReasons`. Снижение бюджета действующей кампании вступает в силу со следующей полуночи по часовому поясу счёта. Повышение применяется сразу. [Состояния и управление](https://create.roblox.com/docs/cloud/guides/advertising#track-review-and-delivery)

<a id="reports"></a>

## Фактические расходы, клики и показы

Прогноз до запуска возвращает Ads API. Отчёт по фактическим результатам запрашивается отдельно через `POST https://apis.roblox.com/analytics-query-api/v1/universes/{universeId}/metrics`. Ключу требуется `universe.analytics:read` для выбранной игры. Один запрос получает одну метрику. [Analytics Query API](https://create.roblox.com/docs/cloud/guides/analytics)

| Показатель | Имя для API | Единица |
|---|---|---|
| Расходы | `SponsoredAdsSpendUsd` | USD |
| Показы | `SponsoredAdsImpressions` | показы |
| Клики | `SponsoredAdsClicks` | клики |

Пример дневных расходов по объявлениям за одну завершённую дату UTC. Значение `endTime` исключается из интервала. Поддерживаемая детализация этих метрик — `OneHour`, `OneDay` и `None`. [Метрики и измерения](https://create.roblox.com/docs/cloud/guides/analytics/metrics)

```json
{
  "metric": "SponsoredAdsSpendUsd",
  "granularity": "OneDay",
  "startTime": "2026-11-17T00:00:00Z",
  "endTime": "2026-11-18T00:00:00Z",
  "breakdown": ["AdId"]
}
```

При `done=true` ряды находятся в `response.values`. При HTTP 202 и `done=false` опрашивайте операцию по полученному `path`. Для связи с кампанией сопоставьте `AdId` и поле `id` из `GET /campaigns/{campaignId}/ads`. Эти три метрики не содержат атрибутированные запуски игры. [Операции аналитики](https://create.roblox.com/docs/cloud/guides/analytics#long-running-operations) · [Рекламные показатели](https://create.roblox.com/docs/cloud/guides/advertising#report-on-performance)

Доступные разрезы трёх метрик: `AdId`, `CampaignId`, `AgeGroup`, `Gender`, `OperatingSystem`, `Platform`. Срок хранения — 1468 дней. Для опроса операции используйте `GET https://apis.roblox.com/analytics-query-api/{path}`, подставив значение из ответа. [Каталог метрик](https://create.roblox.com/docs/cloud/guides/analytics/metrics#sponsored-ads)

<a id="errors"></a>

## Обработка ошибок

При ошибке Ads API обычно возвращает [ErrorEnvelope](#model-errorenvelope). Переберите `errors[]`: `code` и `reason` подходят для программного разбора, `field` указывает на проблемное поле, `remediation` и `actionUrl` помогают устранить причину. При `retryable=true` запрос можно повторить. Шлюз аутентификации может вернуть другую форму ответа. [Обработка ошибок в Ads API](https://create.roblox.com/docs/cloud/guides/advertising#handle-errors)

| HTTP | Когда встречается | Что проверить |
|---|---|---|
| 400 | `INVALID_ARGUMENT`, `FAILED_PRECONDITION` | Формат ID и сумм, обязательные поля, допустимые изменения. Например, `BELOW_MINIMUM`, `UNKNOWN_FIELD`, `IMMUTABLE_FIELD`. Для оконченной кампании или удалённого объявления учитывайте текущее состояние. |
| 401 | Шлюз отклонил ключ | Проверьте срок действия, состояние ключа и исходный IP. |
| 403 | Недостаточно прав или отсутствует аутентификация | Проверьте область доступа и право владельца на игру, счёт и изображение. `UNIVERSE_NOT_ADVERTISABLE` относится к запрошенной игре. |
| 404 | `NOT_FOUND` | Проверьте ID и выбранный счёт. Для закрытого доступа сервис также может вернуть 404. |
| 409 | `ALREADY_EXISTS`, `ABORTED`, `FAILED_PRECONDITION` | Уточните регистрацию изображения и состояние объявления. При конфликте записи заново получите ресурс перед изменением. |
| 429 | `RESOURCE_EXHAUSTED` | Уменьшите частоту запросов. При повторе незавершённого создания сохраните исходные тело и ключ идемпотентности. |
| 500, 503, 504 | Внутренняя ошибка или тайм-аут | Повторяйте с увеличивающейся задержкой. Для создания используйте тот же ключ идемпотентности. |

У проверки бюджета и оплаты есть причины `INSUFFICIENT_AD_CREDIT`, `PAYMENT_ACTION_REQUIRED`; результат пробного запроса может содержать их при HTTP 200 и `valid=false`. Если ответ содержит `actionUrl`, используйте указанный Roblox экран оплаты. [Ошибки оплаты](https://create.roblox.com/docs/cloud/guides/advertising#payment-errors)

<a id="related"></a>

## Смежные методы раздела Advertising

Creator Hub объединяет под заголовком Advertising ещё 15 операций других сервисов. У них собственные хосты и условия доступа. В частности, для записи кликов используется отдельный сервис. Для каждого метода полная исходная карточка доступна в общем [справочнике Advertising в Markdown](https://create.roblox.com/docs/cloud/reference/features/advertising.md).

| Хост | Метод и исходная карточка |
| --- | --- |
| `ads.roblox.com` | [`POST /v1/ads-tracking/click`](https://create.roblox.com/docs/cloud/reference/features/advertising#ads_post_v1_ads_tracking_click) |
| `ads.roblox.com` | [`POST /v1/sponsored-games/click`](https://create.roblox.com/docs/cloud/reference/features/advertising#ads_post_v1_sponsored_games_click) |
| `ads.roblox.com` | [`GET /v1/sponsored-pages`](https://create.roblox.com/docs/cloud/reference/features/advertising#ads_get_v1_sponsored_pages) |
| `ads.roblox.com` | [`GET /v1/sponsored/catalog-assets/{targetId}/create`](https://create.roblox.com/docs/cloud/reference/features/advertising#ads_get_v1_sponsored_catalog_assets__targetId__create) |
| `adconfiguration.roblox.com` | [`GET /v2/sponsored-campaigns`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_get_v2_sponsored_campaigns) |
| `adconfiguration.roblox.com` | [`POST /v2/sponsored-campaigns/create`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_sponsored_campaigns_create) |
| `adconfiguration.roblox.com` | [`GET /v2/sponsored-campaigns/eligible-asset-type-ids`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_get_v2_sponsored_campaigns_eligible_asset_type_ids) |
| `adconfiguration.roblox.com` | [`POST /v2/sponsored-campaigns/eligible-campaign-targets`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_sponsored_campaigns_eligible_campaign_targets) |
| `adconfiguration.roblox.com` | [`GET /v2/sponsored-campaigns/multi-get-can-user-sponsor`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_get_v2_sponsored_campaigns_multi_get_can_user_sponsor) |
| `adconfiguration.roblox.com` | [`POST /v2/sponsored-campaigns/stop`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_sponsored_campaigns_stop) |
| `adconfiguration.roblox.com` | [`GET /v2/sponsored-games`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_get_v2_sponsored_games) |
| `adconfiguration.roblox.com` | [`POST /v2/sponsored-games/create`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_sponsored_games_create) |
| `adconfiguration.roblox.com` | [`POST /v2/sponsored-games/stop`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_sponsored_games_stop) |
| `adconfiguration.roblox.com` | [`GET /v2/sponsored-games/universes`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_get_v2_sponsored_games_universes) |
| `adconfiguration.roblox.com` | [`POST /v2/tracking/click`](https://create.roblox.com/docs/cloud/reference/features/advertising#adconfiguration_post_v2_tracking_click) |

## Источники и версия

Контракты и названия полей принадлежат Roblox Corporation. Русские пояснения, таблицы и примеры адаптированы для этого справочника. Описания в Creator Docs распространяются по CC BY 4.0, примеры кода — по MIT. [Условия репозитория Roblox](https://github.com/Roblox/creator-docs/blob/main/LICENSE) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

- Машиночитаемая спецификация OpenAPI 3.0.4, зафиксированная ревизия `2f1abb9e08fd42cba37cb0d69f5b303cc1432ee1`. [Скачать JSON](https://raw.githubusercontent.com/Roblox/creator-docs/2f1abb9e08fd42cba37cb0d69f5b303cc1432ee1/content/en-us/reference/cloud/openapi.json)
- Полная публикация Roblox по разделу Advertising. [Оригинал на английском в Markdown](https://create.roblox.com/docs/cloud/reference/features/advertising.md) · [HTML-версия](https://create.roblox.com/docs/cloud/reference/features/advertising)
- Правила кампаний и интеграция с Ads Manager. [Руководство по Ads API](https://create.roblox.com/docs/cloud/guides/advertising) · [Портал и биллинг](https://create.roblox.com/docs/production/promotion/ads-manager)
- Источник статистики. [Analytics Query API](https://create.roblox.com/docs/cloud/guides/analytics) · [Метрики Sponsored Ads](https://create.roblox.com/docs/cloud/guides/analytics/metrics#sponsored-ads)
