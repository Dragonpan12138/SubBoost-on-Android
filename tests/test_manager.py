"""Offline checks for the documentation helpers; no phone or network needed."""
import importlib.util
from importlib.machinery import SourceFileLoader
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'scripts' / 'subboost'
loader = SourceFileLoader('phone_manager', str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
manager = importlib.util.module_from_spec(spec)
with patch.dict(os.environ):
    loader.exec_module(manager)


class ManagerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        root = Path(self.directory.name)
        self.envfile = root / '.env'
        self.envfile.write_text('APP_URL=http://127.0.0.1:3000\nJWT_SECRET=test-only\n')
        self.state = root / 'state'
        self.state.mkdir()
        for name, value in {
            'ENVFILE': self.envfile, 'STATE': self.state,
            'SOCKET': self.state / 'run', 'LOGS': self.state / 'logs',
            'PGDATA': self.state / 'postgres',
        }.items():
            patcher = patch.object(manager, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def test_public_url_preserves_secret(self):
        with patch.object(manager.sys, 'argv', ['subboost', 'public-url', 'https://subboost.example.com/']):
            manager.public_url()
        self.assertEqual(manager.settings()['APP_URL'], 'https://subboost.example.com')
        self.assertEqual(manager.settings()['JWT_SECRET'], 'test-only')

    def test_reject_unsafe_public_urls(self):
        before = self.envfile.read_text()
        for url in ['http://example.com', 'https://user:pass@example.com',
                    'https://example.com/path', 'https://example.com/?secret=test',
                    'https://example.com/#token=test', 'https://exa\nmple.com']:
            with self.subTest(url=url):
                with patch.object(manager.sys, 'argv', ['subboost', 'public-url', url]):
                    with self.assertRaises(RuntimeError):
                        manager.public_url()
        self.assertEqual(self.envfile.read_text(), before)

    def test_local_enable_does_not_enable_tunnel(self):
        with patch.object(manager.sys, 'argv', ['subboost', 'enable']):
            manager.main()
        self.assertTrue((self.state / 'enabled').exists())
        self.assertFalse((self.state / 'tunnel-enabled').exists())

    def test_tunnel_enable_requires_existing_token_file(self):
        (self.state / 'tunnel-token').write_text('test-only')
        with patch.object(manager.sys, 'argv', ['subboost', 'enable']):
            manager.main()
        self.assertTrue((self.state / 'tunnel-enabled').exists())

    def test_pg_version_alone_is_not_initialized(self):
        manager.PGDATA.mkdir()
        (manager.PGDATA / 'PG_VERSION').write_text('17')
        with self.assertRaisesRegex(RuntimeError, 'not initialized'):
            manager.db_start()

    def test_stop_when_nothing_is_running(self):
        with patch.object(manager, 'process_pid', return_value=None):
            with patch.object(manager.subprocess, 'run') as run:
                run.return_value.returncode = 3
                with patch.object(manager, 'command') as command:
                    manager.stop()
                    command.assert_not_called()


if __name__ == '__main__':
    unittest.main()
