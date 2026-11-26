"""BT-91. Original shell, glazing, swept stabilizers and slotted exhaust in studs."""
from math import cos, radians, sin

PAINT = (4, 164, 171)
EDGE = (24, 201, 199)
SEAM = (10, 65, 76)
STEEL = (24, 99, 108)


def shapes(add):
    def shell(name, shape, size, pos, color, rot=(0, 0, 0)):
        add('PodHull', name, shape, size, pos, color, 'Metal', rot)

    shell('Keel', 'Ball', (2.25, 1.65, 4.82), (0, -.26, -.17), SEAM)
    shell('PressureHull', 'Ball', (2.5, 2.18, 4.9), (0, -.02, -.1), PAINT)
    shell('NoseSkid', 'Ball', (1.48, .5, 2.03), (0, -.12, -1.585), EDGE, (-6, 0, 0))
    for side in (-1, 1):
        suffix = 'L' if side == -1 else 'R'
        shell('Chine' + suffix, 'Ball', (.36, .38, 3.23),
              (side * 1.02, -.25, -.08), STEEL, (0, -side * 4, side * 5))
        for i in range(3):
            shell('Intake' + suffix + str(i), 'Block', (.10, .46, .085),
                  (side * 1.17, -.30, .36 + .21 * i), SEAM, (17, 0, 0))
        add('Stabilizers', 'Foil' + suffix, 'Wedge', (.79, .35, 1.5),
            (side * 1.48, -.37, .65), PAINT, 'Metal', (-5, side * 15, -side * 12))
        add('Stabilizers', 'FoilEdge' + suffix, 'Ball', (.16, .19, 1.16),
            (side * 1.78, -.40, .63), EDGE, 'Metal', (-5, side * 15, -side * 12))
    add('Cockpit', 'CanopyFrame', 'Ball', (1.98, 1.13, 3.23), (0, .53, -.49),
        STEEL, 'Metal', (-13, 0, 0))
    add('Cockpit', 'SmokedCanopy', 'Ball', (1.87, 1.39, 3.03), (0, .61, -.5),
        (12, 24, 49), 'SmoothPlastic', (-13, 0, 0))
    add('Cockpit', 'ReflectedSky', 'Ball', (.33, .055, 1.27), (.45, 1.22, -.56),
        (65, 101, 135), 'SmoothPlastic', (-13, 0, -21))
    for name, z, r, thickness, shade in [('Collar', 1.6, 1.05, .53, STEEL),
                                        ('RearRim', 2.09, 1.10, .57, PAINT),
                                        ('RimLip', 2.47, .99, .26, EDGE)]:
        for i in range(10):
            a = i * 36
            add('RearRing', name + str(i), 'Block',
                (2 * r * sin(radians(18)) * 1.12, .32, thickness),
                (r * sin(radians(a)), r * cos(radians(a)), z),
                shade, 'Metal', (0, 0, -a))
    add('RearRing', 'Recess', 'Cylinder', (.15, 1.66, 1.66), (0, 0, 2.01),
        SEAM, 'Metal', (0, 90, 0))
    add('RearRing', 'TurbineHub', 'Cylinder', (.10, .60, .60), (0, 0, 2.14),
        (73, 221, 225), 'Neon', (0, 90, 0))


ATTACHMENTS = {'PathMount': (0, 0, 0), 'NoseDirection': (0, 0, -2.60),
               'Exhaust': (0, 0, 2.50), 'TrailOrigin': (0, 0, 2.53),
               'ImpactVFX': (0, 0, -2.45), 'BoundsCenter': (0, 0, 0)}
STATES = ['Dormant', 'Enter', 'CrossingForward', 'TurnAtBound', 'CrossingReturn',
          'PassExit', 'Impact', 'Removed', 'Cleanup']
