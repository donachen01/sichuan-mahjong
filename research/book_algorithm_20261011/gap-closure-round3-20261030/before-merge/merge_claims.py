"""Merge this round's four fixed, disjoint terminal-world shards only."""
from pathlib import Path
import json, hashlib

P=Path(__file__).resolve().parent
worlds=json.loads((P/'claim-worlds.json').read_text())
index={r['id']:i for i,r in enumerate(worlds['rows'])}
rows=[];seen=set();hashes={}
for shard in range(4):
    path=P/f'full-claims-shard{shard}.json'
    data=json.loads(path.read_text())
    assert not data['failures'] and len(data['rows'])==128,('Incomplete shard',shard)
    assert data['pools']==worlds['pools']
    for row in data['rows']:
        assert index[row['id']]%4==shard
        key=(row['id'],row['root'])
        assert key not in seen and row['fully_settled']
        seen.add(key);rows.append(row)
    hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
assert seen=={(w['id'],arm) for w in worlds['rows'] for arm in ['pass','peng']}
rows.sort(key=lambda r:(index[r['id']],r['root']))
(P/'full-claims.json').write_text(json.dumps(dict(rows=rows,failures=[],pools=worlds['pools'])))
(P/'full-claims-merge.json').write_text(json.dumps(dict(games=len(rows),unique_arms=len(seen),
    shard_sha256=hashes,scope='Fixed world-index partition; no outcome selection, duplicate completed arms or incomplete games.'),indent=2))
print('Merged512 complete games;256 exact paired worlds; no overlap.')
