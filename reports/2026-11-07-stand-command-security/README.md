# BT-58: команды CombatStand через реальные Studio-клиенты

7 ноября 2026. Ограниченный технический срез BT-58; связанные BT-16/BT-18/BT-57. [Draft PR #2](https://github.com/Dimkox/bricktoads/pull/2), ветка `bt-18-combat-stand`, исходная база `9029e4ec90ff010ca9f314b494869d2fb2c53b15`. Полная задача BT-58 остаётся в работе.

## Результат

**PASS: 48 сценариев / 486 проверок, 0 FAIL.** Реальный сервер Studio 0.746.0.7461269 и два реальных клиента; после ухода второго добавлен новый третий UserId как наблюдатель. Сценарии заняли48.11s без запуска сессии. Все шесть настроек delay/jitter/loss равны0 и не менялись. Это не повтор 4G/mobile-матрицы.

Сборка `build/CombatStand.rbxlx`:62499 байт, SHA-256 `f0e1cabb7325220a8de39b9127e6a7dca717a1ee2c059d337b1048e5cce55063`. Все семь runtime Source в Studio точно сверены с исходниками. Builder не включает acceptance runner, security module или тестовый клиент. `places/BrickToads.rbxlx` и `RunLifecycle.lua` не менялись.

## Два воспроизведённых дефекта

| Дефект | До исправления | Исправление и финальный результат |
|---|---|---|
| Sync / отклонённый Start рассылали snapshot всем | 30 Sync от P2: P1 получил35 State за0.5496s, бюджет12. RED:29 checks PASS /1 FAIL | Ответ адресуется запросившему; успешный Start и Heartbeat остаются общими. Sync:5 State за0.5658s; отклонённый Start:5 за0.5507s, оба при бюджете12 |
| Успешная команда сохраняла literal OK как notice | После допустимого пакета наблюдалось OK вместо очистки. RED:343 checks PASS /1 FAIL | Конструкция `condition and nil or code` заменена явным if/else; успешный Start тоже очищает notice. После допустимых пакетов notice отсутствует |

Оба исправления ограничены `src/stand/server/Stand.server.lua`. Урон, правила защиты, параметры и физическая калибровка не менялись.

## Проверено в движке

- Строка/число/boolean/nil/Instance вместо таблицы; отсутствующий/вложенный/неизвестный kind; лишние поля Start/Sync; вложенное действие; клиентские damage/target/userId/time; неизвестная атака, строки длиннее160.
- Поддельные run/actor/attempt/level/connection; отрицательный, дробный, строковый, слишком большой sequence; NaN/Infinity в seq и движении; недопустимый вектор. Специальные значения создаются настоящим клиентом непосредственно перед FireServer, не передаются через JSON.
- Полный чужой пакет от другого отправителя; повтор принятой атаки после cooldown; старый Attack после более нового Move; допустимый пакет в той же сессии после malformed-трафика.
- Все120 Attack реально дошли до серверного наблюдателя. После полного восстановления — ровно один AttackAccepted и один Hit; идентичность/запас сохранены, следующий допустимый пакет принят.
- Все120 Sync дошли до сервера; отправитель получил43 State за0.3676s при верхнем бюджете65 (существующий bucket40/s, heartbeat10/s, запас наблюдения). Это ограничение обработки/ответов, не измерение пропускной способности Roblox или полной пользовательской задержки.
- Реальное падение и respawn создали Normal shield. Недопустимая атака не сняла его. Настоящий пакет прежнего actor после respawn получил STALE_ACTOR; сохранённый пакет прежнего run после нового старта — WRONG_RUN.
- После фактического удаления P2 и AddPlayers новый UserId не получил героя. Он не управляет прежним телом и получает HOST_ONLY при Start.

Для отказов сравниваются Life, actor/attempt/run/level/connection, connected/dying, запас, тип/срок защиты; не меняются counts AttackAccepted/Hit/ConfirmedDeath/CommitSpawn/SetHealth. Допустимые Move подтверждаются отсутствием notice, атаки — серверными событиями/эффектом. Наблюдатель [ScriptContext.Error](https://create.roblox.com/docs/reference/engine/classes/ScriptContext) не зарегистрировал ошибок во время матрицы.

Reply не считается выполнением Intent: runner ждёт отдельного OnServerEvent и более позднего State. Для молча отброшенного шлюзом malformed-пакета notice может остаться от предыдущей команды; он не используется как подтверждение кода отказа этого пакета. Evidence сохраняет это различие.

## Воспроизводимость и доказательства

1. Собрать `tools/build_combat_stand.py`, открыть generated place, сверить семь runtime Source.
2. В несохранённую Studio-копию добавить обычные acceptance server/client scripts и `tests/stand/CombatStandSecurityScenarios.lua` как ModuleScript `ServerScriptService.CombatStandSecurityScenarios`. Исполнение ограничено IsStudio и test tag, файлы исключены из builder.
3. В Edit оценить `tools/studio_launch_combat_acceptance.luau`, вызвать launcher с `{name="Security",players=2,securityOnly=true,timeoutSeconds=180}`. Для короткой fanout-регрессии добавить `securityPhase="fanout"`.
4. Прочитать Status/Chunks/Bytes из `ServerStorage.CombatStandAcceptanceEvidence.Security`, склеить ChunkNNNN. После сохранения результатов убрать временные scripts/evidence из Editor.

`manifest.json` содержит SHA-256 трёх JSON-результатов, нормализованных UTF-8/LF исходников финального прогона, базовый commit и хеш сборки. Сохранённый JSON имеет завершающий LF, его размер на1 байт больше строки launcher.

- `baseline-fanout-fail.json`: исходный runtime, воспроизведённая общая рассылка.
- `notice-clear-fail.json`: fanout исправлен, success notice ещё исходный. Эти RED использовали более ранние редакции security harness; финальные source-хеши не приписываются им.
- `security-final-pass.json`: расширенная финальная матрица486/48, соответствующая manifest. Промежуточный полный PASS386/46 не используется как отдельное доказательство.

Локальные проверки: Combat318 assertions, Session37 сценариев (добавлено7), lifecycle46 тестов включая120 последовательностей; Python7+6+3; компиляция13 scripts; обе воспроизводимые сборки — PASS. Новые тесты существующего Session сразу прошли; RED для них не заявляется. Оба runtime-дефекта предварительно воспроизведены engine RED.

## Открытые границы

- Настоящий reconnect прежнего UserId в тот же живой сервер, включая пересечение старого/нового Player. Поддельный connectionEpoch99 его не заменяет.
- Прежнее недостигнутое предусловие pending attack после фактического disconnect. Этот прогон его не повторяет и не закрывает.
- Телефон/планшет, touch, производительность, 4G для этой новой матрицы, изоляция нескольких полноценных групп.
- NPC/takeover, человеческие противники, очередь/резерв босса, межуровневый/межсерверный маршрут, полный уровень: отсутствуют в стенде.
- В движке недопустимая атака проверена под Normal, не Emergency; обе защиты и rate-limited Attack дополнительно покрыты pure Session.

Полнота BT-16/BT-18/BT-26/BT-33/BT-57/BT-58 и публикация experience не объявляются.
