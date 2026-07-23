# third-party

收录的外部 skill，每个一个子目录：

```
third-party/<skill-name>/
├── SKILL.md      # 原样或最小适配
└── SOURCE.md     # 出处 URL / 原作者 / 许可证 / 收录日期 / 本地改动说明
```

## 收录流程

1. 先用 [security-audit](../skills/security-audit/) 审查待收录 skill——SKILL.md 会被模型当作指令执行，等同供应链风险
2. 补齐 `SOURCE.md`
3. 尊重原许可证；不允许再分发的不收录

`install.sh` 不软链本目录——外部 skill 需手动逐个软链，显式启用。
