#!/usr/bin/env python3
from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f'{path}: expected exactly one architecture/UI anchor, found {count}: {old[:120]!r}'
        )
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


root = Path(__file__).resolve().parents[2]
room = root / 'lib/features/room/presentation/room_screen.dart'

# Presentation must depend on the application port, never the infrastructure implementation.
replace_once(
    room,
    "import 'package:synctv_app/features/room/infrastructure/desktop_web_playback_client.dart';\n",
    '',
)
replace_once(
    room,
    "  final WebPlaybackClient _webPlaybackClient =\n"
    "      const NativeDesktopWebPlaybackClient();\n",
    "  late final WebPlaybackClient _webPlaybackClient;\n",
)
replace_once(
    room,
    "    _playbackGateway = DependencyScope.read<RoomPlaybackGateway>(context);\n"
    "    _playbackController = RoomPlaybackController();\n",
    "    _playbackGateway = DependencyScope.read<RoomPlaybackGateway>(context);\n"
    "    _webPlaybackClient = DependencyScope.read<WebPlaybackClient>(context);\n"
    "    _playbackController = RoomPlaybackController();\n",
)

# Keep presentation primitives behind the project's guarded UI components.
replace_once(
    room,
    "            if (_webPlaybackOpening)\n"
    "              const CircularProgressIndicator()\n",
    "            if (_webPlaybackOpening)\n"
    "              const AppLoadingIndicator()\n",
)

print('web playback architecture and UI guard fixes applied')
