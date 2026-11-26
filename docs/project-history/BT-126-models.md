# BT-126. Сверка 33 моделей с релизом v20

27 ноября 2026 года, Москва. Статусы отражают поставку по каждой спецификации. Сверены сценарии из опубликованного файла v20, GLB в GitHub, манифесты и результаты предыдущих проверок Studio. Нового прогона Studio в рамках этой сверки не было. Число поз означает количество записанных образцов. Для Spike, Rocket и Gear сопоставление проверено по интервалам исходных обработчиков в каталоге реквизита. В индивидуальных GLB не обнаружены именованные уровни детализации или расширение MSFT_lod. Протокол приёмки отдельных LOD по ТЗ не найден.

[Релиз](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/releases/roblox/v20/verification.json) · [Проверка поз в Studio](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/reports/2026-11-11-full-campaign-cast-audio/full-catalog-a244.json) · [Происхождение реквизита](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/props/canonical-course/source/source-catalog.json) · [Стандарт сдачи](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/MODEL_STANDARDS_RU.md)

## BT-75

**Boss Walker** · В работе. В релизе используется Guardian из трёх частей. В Studio проверены отдача обеих пушек и сохранение коллайдера.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Сверить симметричный корпус и заднюю геометрию с UHD-референсом; приложить контрольную трассу очередей обеих пушек.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/superpowers/specs/2026-11-09-boss-walker-full-model-spec-ru.md) · [Guardian, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-hero/boss-walker.glb)

## BT-76

**Big Blag** · В работе. BigBlag — 7 частей, 16 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить BellyContact относительно серверного объёма при приземлении, промахе и защищённой цели.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/bosses/big-blag.md) · [BigBlag, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/BigBlag/BigBlag.glb)

## BT-77

**Robo-Manus** · В работе. RoboManus — 8 частей, 16 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать вылет снаряда из оружейной точки без пересечения брони и прерывание прыжка на двух клиентах.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/bosses/robo-manus.md) · [RoboManus, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/RoboManus/RoboManus.glb)

## BT-78

**General Slaughter** · В работе. GeneralSlaughter — 7 частей, 16 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить контакт рогов при Charge и Headbutt, промах и отсутствие повторного урона в одной атаке.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/bosses/general-slaughter.md) · [GeneralSlaughter, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/GeneralSlaughter/GeneralSlaughter.glb)

## BT-79

**Buzzball** · В работе. Buzzball — 2 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить сохранение игрового радиуса при смене LOD, позднее подключение и бюджет четырёх арен.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/bosses/buzzball.md) · [Buzzball, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Buzzball/Buzzball.glb)

## BT-80

**Dark Queen** · В работе. DarkQueen — 9 частей, 16 проверенных образцов поз в каталоге Studio. Для шарнира Hair есть отдельная проверка импорта и сброса.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить ось вращения и точки кистей по UHD-ригу, затем задокументировать мобильную приёмку вихря.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/bosses/dark-queen.md) · [DarkQueen, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/DarkQueen/DarkQueen.glb)

## BT-81

**Psyko Pig** · В работе. Pig — 7 частей, 22 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать обе палитры рядом, различимость трёх атак до контакта и сохранение владельца при броске.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/psyko-pig.md) · [Pig, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Pig/Pig.glb)

## BT-82

**Walker и Tall Walker** · В работе. Walker — 5 частей, 19 проверенных образцов поз в каталоге Studio. Для Tall Walker также есть отдельный GLB; доработка ног вошла в ноябрьскую поставку.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Сдать оба ростовых варианта с проверкой опор в крайних позах и выдачи одной дубины при смерти.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/walker.md) · [Walker, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Walker/Walker.glb)

## BT-83

**Dragon** · В работе. Dragon — 10 частей, 16 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить посадку, отмену захвата и высадку с сохранением тела дракона, его здоровья и владельца.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/dragon.md) · [Dragon, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Dragon/Dragon.glb)

## BT-84

**Raven и большой мутант** · В работе. Raven — 8 частей, 13 проверенных образцов поз в каталоге Studio. LargeRaven — 8 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать обе формы клюва и полный цикл отделяемого когтя мутанта от падения до подбора и удаления.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/raven.md) · [Raven, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Raven/Raven.glb) · [LargeRaven, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/LargeRaven/LargeRaven.glb)

## BT-85

**Saturn Toadtrap** · В работе. SaturnToadtrap — 3 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать силуэт с обеих стен, крепление основания и крайние положения сегментов при атаке.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/saturn-toadtrap.md) · [SaturnToadtrap, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/SaturnToadtrap/SaturnToadtrap.glb)

## BT-86

**Retro Blaster** · В работе. RetroBlaster — 5 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить крепление WallAnchor и положение дула при наведении и отдаче с обеих сторон шахты.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/retro-blaster.md) · [RetroBlaster, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/RetroBlaster/RetroBlaster.glb)

## BT-87

**Vader** · В работе. Invader — 5 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Приложить проверку однократного возврата жетона жизни, выхода за время ожидания и смены попытки.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/vader.md) · [Invader, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Invader/Invader.glb)

## BT-88

**Scuzz** · К выполнению. В каталоге найден RacingRat для Giblet (0x46). Отдельное представление Scuzz (0x47) не подтверждено.

Не найдены отдельный экспорт этой модели, три уровня детализации и акт приёмки по ТЗ. Изготовить отдельную групповую крысу типа 0x47, различимую рядом с Giblet; проверить две атаки и прерывание после смены уровня.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/scuzz.md)

## BT-89

**Giblet** · В работе. RacingRat — 7 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить силуэт соперника у бомбы и прерывание забега при сбросе этапа.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/giblet.md) · [RacingRat, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/RacingRat/RacingRat.glb)

## BT-90

**Rat Rocket** · В работе. RocketRat — 7 частей, 13 проверенных образцов поз в каталоге Studio. Металлическая ракета вошла в поставку BT-114.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать устойчивую посадку крысы и единственный сброс препятствия при редких обновлениях и позднем подключении.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/rat-rocket.md) · [RocketRat, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/RocketRat/RocketRat.glb)

## BT-91

**Rat Pod** · К выполнению. В игре есть трасса и RocketRat. Отдельная капсула Rat Pod с привязкой к object_turbo_tunnel_fly_obstacle не подтверждена.

Не найдены отдельный экспорт этой модели, три уровня детализации и акт приёмки по ТЗ. Изготовить бирюзовую капсулу с кольцевым хвостом; проверить оба разворота, контакт на скорости и очистку следа после возврата к контрольной точке.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/rat-pod.md)

## BT-92

**Mr Frosty** · В работе. Snowman — 6 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить отдельный снежный снаряд, его выпуск и соответствие позам рига снеговика.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/mr-frosty.md) · [Snowman, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Snowman/Snowman.glb)

## BT-93

**Spike Back** · В работе. В релизе используется Spike; исходный обработчик совпадает с указанным в ТЗ.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Сопоставить сиреневое основание и шипы с утверждённым видом, проверить границу контакта при развороте и прыжке над препятствием.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/spike-back.md) · [Spike, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/props/canonical-course/Spike/Spike.glb)

## BT-94

**Karnath** · В работе. Snake — 4 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить стыки сегментов и устойчивость игрока на движущейся змее в четырёх комнатах.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/karnath.md) · [Snake, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Snake/Snake.glb)

## BT-95

**Meteorite** · К выполнению. Для Ember Airway существуют воздушные препятствия. Отдельный prefab Meteorite для типа 0x69 не подтверждён.

Не найдены отдельный экспорт этой модели, три уровня детализации и акт приёмки по ТЗ. Изготовить отдельную опасность типа 0x69; показать читаемое без свечения ядро, совпадение с зоной контакта и очистку хвоста после сброса.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/meteorite.md)

## BT-96

**Missile** · В работе. В релизе используется Rocket; исходный обработчик совпадает с указанным в ТЗ.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить обе ориентации ракеты, след от сопла, однократный контакт и очистку при возврате к контрольной точке.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/missile.md) · [Rocket, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/props/canonical-course/Rocket/Rocket.glb)

## BT-97

**Sentry Drone** · В работе. SentryDrone — 3 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить обе точки выстрела, отделяемый снаряд и узнаваемость корпуса на мобильном качестве.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/sentry-drone.md) · [SentryDrone, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/SentryDrone/SentryDrone.glb)

## BT-98

**Snotball** · В работе. Slug — 4 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать крайние деформации слизня, отсутствие дыр и сохранение силуэта при упрощении сетки.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/snotball.md) · [Slug, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Slug/Slug.glb)

## BT-99

**Mechno Droid** · В работе. Robot — 4 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить выстрел из лицевой решётки, различимость Bolt и Explode, очистку эффекта взрыва.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/mechno-droid.md) · [Robot, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Robot/Robot.glb)

## BT-100

**Krazy Kog** · В работе. В релизе используется Gear; исходный обработчик совпадает с указанным в ТЗ.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Сопоставить обод с контактным контуром и показать поведение внутреннего отверстия на действующем маршруте.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/krazy-kog.md) · [Gear, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/props/canonical-course/Gear/Gear.glb)

## BT-101

**Electra Eel** · В работе. Electrofish — 3 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить хвост при крайнем изгибе, предупреждение перед разрядом в воде и отключение эффекта.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/electra-eel.md) · [Electrofish, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Electrofish/Electrofish.glb)

## BT-102

**Hammerfish** · В работе. Hammerfish — 7 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать крайние положения челюсти и хвоста, торможение и работу обоих профилей жизни на одной модели.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/hammerfish.md) · [Hammerfish, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Hammerfish/Hammerfish.glb)

## BT-103

**Jawz** · В работе. Shark — 7 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить обе позы Jawz, смыкание зубов без пересечений и три профиля жизни на одном риге.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/jawz.md) · [Shark, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Shark/Shark.glb)

## BT-104

**Steel Beak** · В работе. Duck — 6 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать две исходные позы, прерывание укуса и единственное попадание без выдачи предмета LargeRaven.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/steel-beak.md) · [Duck, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Duck/Duck.glb)

## BT-105

**Hornhead** · В работе. Hordhead — 7 частей, 13 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Показать обе палитры на одной геометрии, крайние позы переката и приземление на вращающейся опоре.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/hornhead.md) · [Hordhead, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Hordhead/Hordhead.glb)

## BT-106

**Swellcheek** · В работе. Swellcheeks — 5 частей, 10 проверенных образцов поз в каталоге Studio.

В поставке не подтверждены три уровня детализации и их приёмка по ТЗ. Проверить форму BC при надувании, выходы эффектов и переход BC/BD с привязкой к типу появления.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/swellcheek.md) · [Swellcheeks, GLB](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/assets/characters/canonical-cast/Swellcheeks/Swellcheeks.glb)

## BT-107

**Shadow Cloud** · К выполнению. В игре есть Swellcheeks и FlyingHead. В ТЗ прямо указано, что связь FlyingHead с образом BD требует отдельного подтверждения.

Не найдены отдельный экспорт этой модели, три уровня детализации и акт приёмки по ТЗ. Подготовить образ BD и его переход к BC, связать sourceGfx и тип каждого появления с игровым объектом; проверить раздельные циклы ветра и газа.

[ТЗ](https://github.com/Dimkox/bricktoads/blob/5a3ccc3c556e4b0bcfaa9f391246ba16861cf65f/docs/models/enemies/shadow-cloud.md)
