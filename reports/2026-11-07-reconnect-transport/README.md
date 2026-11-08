# BT-13: фактические транспортные прогоны через Studio MCP

7 ноября2026, кодовая база `ce518f5902e4a09e92ab053b32709cf76277ab1c`. Проверка продолжена после требования использовать MCP. **Настоящий возврат к прежнему персонажу не подтверждён.** Есть успешные реальные телепорты того же пользователя и воспроизведённые ограничения контекстов; это не PASS полного BT-13 и не доказанный дефект игрового gateway.

## Среда теперь создана

Отдельная experience **BrickToads Reconnect Test**, universe `10775039796`, root place `117412694427208`. Open Cloud GET подтвердил visibility **PRIVATE**; ответ сохранён в `private-experience.json`. Experience создана через Save to Roblox, без публичного релиза. После последнего указания пользователя все дальнейшие действия выполнялись через Roblox Studio MCP, без управления интерфейсом.

Установленная версия Studio: `0.746.0.7461269`. Все проверки использовали один существующий PlaceId и разные ReservedServerId; UserId не менялся вручную. Наличие реальных идентификаторов сняло прежнее предусловие GameId/PlaceId=0, но не означает успешный reconnect.

## Что реально произошло

| Путь | Наблюдение | Статус |
|---|---|---|
| ExecuteMultiplayerTestAsync,2 клиента | Серверный TeleportAsync вернул reserved ID, однако оба клиента вывели `Cannot Teleport in the current Studio context`; сервер сохранил исходных−1/−2 | FAIL транспортного контекста |
| Обычный MCP start_stop_play,1 текущий пользователь Studio | Телепорт в reserved A и затем в B выполнился; GetJoinData сохранил исходный положительный UserId и реальный TeleportData | PASS перехода, не reconnect |
| B→тот же ReservedServerId A | Вход с подтверждённым stage ReturnArenaConfirmed выполнен, но прежние server-local observer/runtime отсутствовали. Дополнительный marker исходного контекста тоже отсутствовал | FAIL предусловия прежнего живого сервера |
| ExecutePlayModeAsync + AddPlayers(1) | Solo Test оставил одного прежнего пользователя. AddPlayers отказал: `can only be called from the server DataModel of a running Studio test session` | FAIL возможности добавить anchor |
| TestService.NumberOfPlayers=2, ExecuteWithStudioRun=true, ExecuteRunModeAsync | Два реальных тестовых клиента действительно созданы. Телепорт снова отвергнут обоими клиентами с тем же current-context сообщением; TeleportInitFailed также зарегистрирован на сервере | FAIL транспортного контекста |

Возвращённый TeleportAsyncResult с privateServerId не считался успешным переходом: проверялись реальные Player/GetJoinData, смена контекста, server-local marker и клиентские сообщения. В multiplayer отказ был зафиксирован по двум клиентским консолям и сохранён в серверный результат через MCP перед EndTest. Run-mode результат содержит также настоящий TeleportInitFailed.

## Подготовка настоящей арены

В reserved A обычного Play через MCP были вставлены **семь настоящих server runtime Source** текущего CombatStand. Исходная сцена припаркована в ServerStorage, Terrain оставлен на месте. Start отправлен настоящим клиентом через Intent RemoteEvent. Штатный presentation-client не вставлялся: этот опыт не проверяет HUD/touch.

Через реальное физическое падение и успешный respawn получена попытка2/остаток2; дождались окончания Normal shield. Затем доверенный Diagnostics.Life подготовил rawLife31. Это подготовка сцены, не доказательство боевого повреждения во время отсутствия. До ухода были сохранены server-local ссылки на прежний Player, actor Model/root, GUID marker, run/actor/attempt, Life31, reserves2, epoch1. `arena-before-departure.json` фиксирует состояние ARMED.

Наблюдатель `observe_actual_reconnect.luau` не запускает новую игру и не восстанавливает персонажа из TeleportData. Его16 проверок возврата могли бы подтвердить прежний UserId/новый Player, прежние observer/actor/root/run/attempt/ресурсы и epoch+2. **Они не выполнились:** исходный observer отсутствовал в вернувшемся контексте. Ни новая арена, ни новое тело для получения PASS не создавались. Возвращаемые HP/actor/reserves через TeleportData не передавались.

В одиночном Studio-прогоне пустая A не сохранила наблюдаемую RAM арены. Это не обещание о сроках жизни production-серверов и не основание вводить искусственное удержание либо восстановление старого run на другом сервере. Для обязательной проверки доступного действующего run нужен второй клиент, остающийся в A; подтверждённого MCP-only режима, сочетающего такого anchor и рабочий Teleport в этой версии, не получено.

## Доказательства

- `private-experience.json` — реальный Open Cloud ответ с PRIVATE и назначенными IDs.
- `multiplayer-context-fail.json` — исходный двухклиентский отказ.
- `arena-before-departure.json` — настоящее состояние before/marker/nonce.
- `ordinary-play-return-precondition.json` — настоящий вход после обратного teleport, прежний observer/runtime отсутствуют.
- `play-mode-add-player-fail.json` — solo PlayMode и отказ AddPlayers.
- `run-mode-two-client-transport-fail.json` — второй способ запуска2 клиентов и отказ транспортного контекста.
- `cleanup-observed.json` — ответы MCP сразу после остановки сервера/двух клиентов и завершения теста; отдельно отмечена более ранняя проверка Editor.

`manifest.json` содержит размеры/SHA-256 payload и нормализованных исходников. Helpers компилируются, не включаются в production builder и не являются готовым продуктовым маршрутизатором. Первичный multiplayer probe использовал раннюю редакцию до дополнительного tag guard; финальные helper-хеши не приписываются ей задним числом. Последующие обычные Play/Run прогоны выполнялись отдельными командами MCP, как описано выше.

## Завершение серии и следующий gate

После прямого RunService.Stop через MCP сервер и оба клиента последнего теста каждый вернули running=false; последующий EndTest вернул endTestOK=true/running=false. Эти ответы сразу после остановки сохранены в `cleanup-observed.json`. Более ранняя проверка основного Editor подтвердила TestService.NumberOfPlayers=0, ExecuteWithStudioRun=false, все6 delay/jitter/loss=0 и пустой ServerScriptService после удаления временных probe scripts/evidence. Последующие read-only запросы к уже закрытым дочерним сессиям оставались без ответа; свежая итоговая проверка через них не заявляется. Production Core/Session/Combat/gateway этой серией не менялись. Локальное изменение `places/BrickToads.rbxlx` существовало до серии и в неё не включается.

Следующий необходимый транспортный gate — Test/Team Test с остающимся вторым участником, в контексте, где Teleport действительно поддержан. Публичного MCP метода запуска Team Test не подтверждено; нельзя выдавать набор test args за такую настройку. Реальный same-user return, сохранение действующих shield deadlines, offline damage/physics, несколько групп и production lifecycle остаются открытыми.

Официальные источники: [поддержка Studio Teleport](https://devforum.roblox.com/t/test-teleports-in-studio/4977640), [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService), [TestService](https://create.roblox.com/docs/reference/engine/classes/TestService), [TeleportOptions](https://create.roblox.com/docs/reference/engine/classes/TeleportOptions). Актуальная документация сообщает поддержку Test/Team Test, но конкретные MCP-контексты выше проверены отдельно и дали указанные результаты.
