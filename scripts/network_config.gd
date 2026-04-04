class_name NetworkConfig
extends Object

# ──────────────────────────────────────────────────────────────────────────────
# Network Configuration
# ──────────────────────────────────────────────────────────────────────────────

enum NetworkEnv { LOCAL, SERVER }

# 이 값을 변경하여 전체 테스트 환경을 전환할 수 있습니다.
const CURRENT_ENV := NetworkEnv.LOCAL

const SERVER_KEY := "defaultkey"
const PORT := 7350

static func get_host() -> String:
	match CURRENT_ENV:
		NetworkEnv.LOCAL:
			return "127.0.0.1"
		NetworkEnv.SERVER:
			return "168.107.26.200"
		_:
			return "127.0.0.1"

static func get_scheme() -> String:
	return "http"

static func get_socket_scheme() -> String:
	return "ws"
