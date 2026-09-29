import hashlib
import json
from pathlib import Path
import subprocess
import urllib.request

request = urllib.request.Request(
    'https://api.github.com/repos/cloudflare/cloudflared/releases/latest',
    headers={'User-Agent': 'SubBoost-phone-deployment'})
with urllib.request.urlopen(request, timeout=30) as response:
    release = json.load(response)
asset = next(item for item in release['assets'] if item['name'] == 'cloudflared-linux-arm64')
expected = asset.get('digest', '')
if not expected.startswith('sha256:'):
    raise RuntimeError('Official release has no SHA256 digest; manual verification needed.')
target = Path('/opt/subboost-tools/cloudflared')
partial = target.with_suffix('.download')
digest = hashlib.sha256()
with urllib.request.urlopen(asset['browser_download_url'], timeout=90) as response:
    with partial.open('wb') as output:
        while block := response.read(1024 * 1024):
            digest.update(block)
            output.write(block)
if digest.hexdigest() != expected.split(':', 1)[1]:
    raise RuntimeError('Cloudflared checksum mismatch; downloaded file was not installed.')
partial.chmod(0o700)
partial.replace(target)
subprocess.run([str(target), '--version'], check=True)
