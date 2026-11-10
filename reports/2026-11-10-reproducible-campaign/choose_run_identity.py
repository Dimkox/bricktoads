"""Choose a short, unique QA run ID with the ordinary production seed hash."""
import json
from itertools import product

MODULUS = 2147483647
TARGET_SEED = 1158731273
PREFIX = 'bricktoads-qa-22-'
HEX = '0123456789abcdef'


def hash_id(value, initial=17):
    result = initial
    for byte in value.encode('ascii'):
        result = (result * 131 + byte) % MODULUS
    return result


def choose():
    halves = [''.join(row) for row in product(HEX, repeat=4)]
    right = {hash_id(value, 0): value for value in halves}
    weight = pow(131, 4, MODULUS)
    for nonce in range(64):
        prefix = f'{PREFIX}{nonce:02x}-'
        prefix_hash = hash_id(prefix)
        for left in halves:
            required = (TARGET_SEED - 1 - hash_id(left, prefix_hash) * weight) % MODULUS
            if required in right:
                value = prefix + left + right[required]
                assert hash_id(value) % (MODULUS - 1) + 1 == TARGET_SEED
                assert len(value) < 100
                return value
    raise RuntimeError('No collision found for the chosen short prefix')


if __name__ == '__main__':
    print(json.dumps({'runId': choose(), 'seed': TARGET_SEED,
                      'method': 'pre-Start one-shot guid dependency; ordinary seedFromId'}))
