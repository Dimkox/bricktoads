# BT-13: привязка к актуальному подключению

7 ноября2026. База `6649ba1ff3fb99ba0840581b07010bffb4ba7eda`, ветка `bt-18-combat-stand`, [draft PR #2](https://github.com/Dimkox/bricktoads/pull/2). Это выполненный срез серверной авторизации подключений. **Настоящий возврат прежнего UserId через транспорт Roblox — NOT RUN; полная BT-13 остаётся в работе.**

## Исправления

Раньше шлюз назначал роль отправителю только по `UserId`; два объекта одного аккаунта могли получать один текущий epoch, попадать в online/host/roster, а повтор PlayerAdded сбрасывал соединение. Проверка PlayerRemoving защищала лишь часть поздних удалений.

Теперь чистый серверный `ConnectionRegistry` хранит текущий объект каждого UserId. Старые/удалённые объекты не принимаются даже с актуальным actor/epoch и не получают собственную роль в State. Повторные join/remove идемпотентны, уход нового объекта не возвращает права старому. Списки online/host/roster используют ту же привязку. Проверка выполняется до любых Intent, включая Sync/Start и bucket. Дополнительно `Parent == Players` отсекает уже ушедший объект до обработки запоздалых callbacks. Слабые ключи metadata без обратных Player-ссылок не удерживают все прежние объекты навсегда.

Изменён только gateway и добавлен модуль привязки. RunLifecycle, Session, Combat, физический адаптер, числа и защита не менялись; основной starter place сохранён.

## Раздельные доказательства

| Проверка | Фактический результат | Что это доказывает |
|---|---|---|
| Исходный настоящий Stand Source, сервисы/транспорт — doubles | 1 PASS /5 FAIL, `gateway-baseline-fail.txt` | Повтор входа менял epoch1→3; старый объект принимал свежую атаку; получал State; возвращался в host; дублировал account при старте |
| Промежуточный gateway до Parent guards | 6 PASS /2 FAIL, `departed-object-fail.txt` | Поздний join отсутствующего объекта и команда уже ушедшего current ещё принимались |
| Финальный настоящий Stand Source с теми же doubles | **14 PASS /0 FAIL**, `gateway-contracts-pass.txt` | Авторизация/рассылка/состав, текущие ресурсы, две защиты, старый epoch, pending attack, один отложенный respawn и spectator |
| ConnectionRegistry + настоящие Core/Session, fake objects/World | **18 PASS /0 FAIL**, `registry-contracts-pass.txt` | Точная идентичность, idempotency, отсутствие fallback, порядок, Life31 без лечения, оба shield deadlines, pending attack и один offline-death respawn |
| Настоящий сервер Studio + реальные клиенты, неизменённая BT-58 matrix | **48 сценариев /486 проверок PASS**, `studio-regression-pass.json`, handlerErrors=[] | Обычные реальные соединения/RemoteEvent, валидные/поддельные/старые команды, физический respawn, настоящий уход и новый spectator после внедрения Registry |

Native gateway fixture **вставляет актуальный Stand.server.lua целиком** в функцию и подставляет только внешние сервисы, World и транспорт. Логика joined/removing/Intent не переписана в тесте. Он не авторизует аккаунт и не создаёт реальный same-user reconnect. Baseline использовал первые6 сценариев, промежуточный RED — первые8; финальный suite дополнен до14. Source-хеши manifest относятся к финальной редакции, не приписываются ранним RED.

Studio0.746.0.7461269: точно сверены Source всех8 runtime scripts/modules, включая Registry. Полная command-матрица заняла52.83s без запуска сессии. Sync и отклонённый Start дали другому клиенту по5 State при бюджете12;120 Sync дали отправителю43 State при бюджете65. Все6 delay/jitter/loss остались0. Это не4G/mobile или настоящий возврат аккаунта. Тестовые scripts/evidence после выгрузки удалены из Editor, новый production Registry оставлен; Studio возвращена в Edit.

Generated CombatStand:64493 байта, SHA-256 `dba4e206b42ce97a1c78cb68b744acbedfa45d6b28963d2554ef62beac71e72b`. Starter:18422байта, прежний SHA-256 `2ea3bf3fd5823fbc0f10d5c744d2acf517510a07d25e910419b8de7ebca24c54`. Acceptance scripts не включены в builder. `manifest.json` фиксирует raw evidence и нормализованные UTF-8/LF source-хеши; JSON launcher сохранён с одним дополнительным завершающим LF. TXT evidence также закреплено в LF для Windows checkout.

## Проверки и воспроизведение

На подготовленном Windows workspace:

```powershell
& .\.tools\luau-0.745\luau.exe tests/run_connections.luau
& .\.tools\python-3.13.9\python.exe tools/test_stand_gateway.py --luau .tools/luau-0.745/luau.exe
& .\.tools\luau-0.745\luau.exe tests/run_stand.luau
& .\.tools\python-3.13.9\python.exe tools/test_combat_stand.py
& .\.tools\python-3.13.9\python.exe tools/build_combat_stand.py --check
```

CI запускает оба новых contract suites и сохраняет их логи. Дополнительно локально пройдены Combat318 assertions, Session37 сценариев, lifecycle46 тестов/120 последовательностей, Python7+6+3, компиляция18 stand/test/launcher scripts и обе воспроизводимые сборки. Native gateway не требует Roblox и не заменяет Studio. Независимое ревью повторило14/18 и проверило границы доказательств.

## Настоящий возврат: остающееся предусловие

`transport-preflight.json` снят через MCP с установленной версии: GameId=PlaceId=0, JobId/PrivateServerId пусты. Reflection показывает `AddPlayers(numPlayers)` без выбора аккаунта; `ExecuteMultiplayerTestAsync` передаёт args тестовым scripts, а не выбирает UserId. Подмена UserId нового клиента не использовалась.

Roblox **5 ноября2026 добавил TeleportAsync в Studio Test/Team Test**, в том числе через MCP: [официальное объявление](https://devforum.roblox.com/t/test-teleports-in-studio/4977640), [актуальное руководство](https://create.roblox.com/docs/projects/teleport), [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService). Прежнее blanket-утверждение «Teleport всегда невозможно тестировать в Studio» устарело.

Возможный отдельный fixture: места A/B одной experience; в reserved A оставить второго клиента и server marker; владельца отправить A→B→тот же reserved A. При возврате проверить прежний UserId, новый объект Player, прежний server marker/run/actor и актуальные HP/запас/дедлайн. Для того же reserved server повторно используется заданный ReservedServerId. Пустые JobId/PrivateServerId local Test не доказывают тот же сервер.

Для этой части запрошена ссылка на существующий приватный тестовый experience. Ненулевые IDs, доступность и фактическое сохранение сервера пока не подтверждены; не использованы выдуманные IDs, cookie-доступ или неподтверждённые Open Cloud mutations. Создание/публикация experience не выполнялись. Это предусловие среды, а не успешная транспортная приёмка.

Также открыты прежний pending-hit после фактического disconnect, мобильные устройства, несколько групп/межуровневый маршрут, NPC/босс/вражеские роли, наблюдение/меню полного продукта и потеря сервера. Этот срез не закрывает BT-13/BT-58/полный прототип.
