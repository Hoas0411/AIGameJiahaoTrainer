# 迭代 003：训练工作站修订资源包

本目录从迭代 001 的失败学习稿复制并修订。`hub.tscn`、`companion.tscn` 和 `tools.tscn` 均为 1600×900 的独立 `Control` 根节点，主题仅引用本目录和 `assets/fonts/NotoSansSC-Medium.ttf`。`author_resources.py` 可再生成两张本地 SVG；删除本目录即可退役整轮资源。

控制器迁移时应将 `UIAppearance.skin()` 的对应 surface 指到这里；本资源包没有改动该运行时选择器。
