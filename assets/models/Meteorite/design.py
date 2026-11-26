"""BT-95. Rounded incandescent front with surface spots and swept flame tongues."""
from math import cos, degrees, pi, sin


def shapes(add):
    add('HotCore', 'GoldenLimb', 'Ball', (2.49, 2.49, 2.30), (0, 0, .24),
        (255, 186, 30), 'SmoothPlastic', (0, 0, 0))
    add('HotCore', 'WhiteFront', 'Ball', (2.46, 2.46, 2.50), (0, 0, 0),
        (255, 249, 176), 'Neon', (0, 0, 0))
    # Shallow dimples on the front hemisphere, oriented to its local tangent.
    for i, (lat, lon, size) in enumerate([(.22, .82, .22), (-.40, .39, .14),
            (.58, -.63, .23), (-.25, -.71, .18), (.05, -.25, .10),
            (.78, .24, .12), (-.65, -.16, .14)]):
        x = 1.23 * cos(lat) * sin(lon)
        y = 1.23 * sin(lat)
        z = -1.25 * cos(lat) * cos(lon)
        add('HotCore', 'Dimple' + str(i), 'Ball', (size, size * 1.30, .076),
            (x, y, z), (233, 164, 36), 'SmoothPlastic', (degrees(lat), -degrees(lon), 0))
    for i in range(8):
        a = 2 * pi * i / 8
        length = (2.10, 2.46, 1.85, 2.30, 2.58, 2.08, 2.36, 1.96)[i]
        shade = [(255, 197, 43), (255, 218, 64), (250, 162, 21)][i % 3]
        # Each curved lobe narrows rearward; its offset includes a small tangential curl.
        for j, (t, radius) in enumerate([(0, .78), (.31, .59), (.57, .37), (.80, .20)]):
            phase = a + .36 * t
            radial = .78 + .33 * t
            add('FlameShell', 'Tongue' + str(i) + '_' + str(j), 'Ball',
                (radius, radius * .91, length * (.66 - .19 * t)),
                (radial * cos(phase), radial * sin(phase), .48 + t * length),
                shade, 'SmoothPlastic', (-9 * sin(phase), 9 * cos(phase), 0))
    add('FlameShell', 'CentralFlare', 'Ball', (1.50, 1.52, 3.22),
        (.08, .02, 1.33), (255, 222, 67), 'SmoothPlastic', (1, 3, 0))
    add('FlameShell', 'LongFlare', 'Ball', (.47, .38, 2.20),
        (.10, .19, 2.59), (255, 194, 36), 'SmoothPlastic', (-5, -5, 0))


ATTACHMENTS = {'FlightCenter': (0, 0, 0), 'Forward': (0, 0, -1.25),
               'TrailOrigin': (0, 0, 2.05), 'ImpactVFX': (0, 0, -1.2),
               'AudioOrigin': (0, 0, 0)}
STATES = ['Neutral', 'WarningPreview', 'SpawnIgnite', 'Flight_A', 'Flight_B',
          'ScrollStopped', 'Impact', 'PassExpire', 'Cleanup']
