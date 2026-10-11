class_name BuildInfo
extends RefCounted
## 构建版本（阶段5）：tools/build_web.sh 导出前写入 res://build_info.json（已 gitignore，导出时打包进 .pck）：
##   {"stage": "5", "commit": "<短提交号>", "dirty": false, "built_at": "<UTC ISO8601>"}
## 文件不存在（编辑器 / 测试 / 未经脚本导出）时视为开发版。HUD 左上角小字显示，QA 截图即可确认版本。

const PATH := "res://build_info.json"

static func data() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return d if d is Dictionary else {}

static func label_text(d: Dictionary = data()) -> String:
	if str(d.get("commit", "")) == "":
		return UiText.t("HUD_BUILD_DEV")
	var c := str(d.commit) + ("+" if bool(d.get("dirty", false)) else "")
	return UiText.t("HUD_BUILD_VERSION", {"stage": str(d.get("stage", "")), "commit": c})
