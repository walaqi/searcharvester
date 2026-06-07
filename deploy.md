# Searcharvester 部署指引

## 前置条件

- Docker 及 Docker Compose（v2.x，即 `docker compose` 命令）
- 至少一个 LLM API 密钥（用于 `/research` deep-research 功能）

---

## 第一步：克隆并进入项目目录

```bash
git clone <仓库地址>
cd searcharvester
```

---

## 第二步：创建 SearXNG 配置文件

```bash
cp config.example.yaml config.yaml
```

然后编辑 `config.yaml`，**必须**修改以下字段：

```yaml
server:
  secret_key: "在这里填入至少32位的随机字符串"
```

生成随机密钥的方法：

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
# 或者
openssl rand -hex 32
```

---

## 第三步：创建 LLM 凭证文件

创建 `.env.hermes` 文件（已被 `.gitignore` 忽略，不会提交到 git）：

```bash
# 根据你使用的 LLM 提供商，至少填写一组
OPENAI_API_KEY=sk-xxx
OPENAI_BASE_URL=https://api.openai.com/v1   # 如使用兼容接口（vLLM/本地）则改为对应地址

# 其他可选提供商
# OPENROUTER_API_KEY=sk-or-xxx
# ANTHROPIC_API_KEY=sk-ant-xxx
# GEMINI_API_KEY=xxx
```

> **重要**：启动时必须通过 `--env-file .env.hermes` 传入，否则 hermes 无法调用 LLM。

---

## 第四步：配置 hermes-data 目录

`hermes-data/` 挂载为 Hermes 的 `HERMES_HOME`，需要存在于宿主机：

```bash
mkdir -p hermes-data/skills
```

如果 `hermes-data/config.yaml` 还不存在，首次启动时容器会自动从镜像内复制默认配置。

**若使用自定义 LLM 端点**，编辑（或创建）`hermes-data/config.yaml`：

```yaml
model:
  provider: "custom"
  default: "你的模型名称"
  base_url: "http://your-endpoint/v1"
```

---

## 第五步：同步自定义 Skills（可选）

项目自带三个 skills（搜索、提取、deep-research），需要同步到 `hermes-data/skills/`：

```bash
for skill in hermes_skills/*/; do
    name=$(basename "$skill")
    rm -rf "hermes-data/skills/$name"
    cp -R "$skill" "hermes-data/skills/$name"
done
```

---

## 第六步：确认 UID/GID（Linux 用户注意）

容器内 `hermes` 用户的 UID/GID 需与宿主机用户一致，挂载目录的权限才正确。默认值为 `501:20`（macOS 典型值）。

Linux 用户请查看自己的 UID/GID：

```bash
id -u  # 通常是 1000
id -g  # 通常是 1000
```

如果不是 `501:20`，在 `.env.hermes` 中追加：

```bash
HERMES_UID=1000
HERMES_GID=1000
```

---

## 第七步：启动所有服务

```bash
docker compose --env-file .env.hermes up -d --build
```

- `--env-file .env.hermes`：将 API 密钥注入容器
- `--build`：首次启动或修改了 `simple_tavily_adapter/` 后需要重新构建

**仅拉取镜像、不构建**（使用预构建的 `ghcr.io/vakovalskii/searcharvester:latest`）：

```bash
docker compose --env-file .env.hermes up -d
```

---

## 验证服务是否正常

```bash
# 查看各容器状态
docker compose ps

# 检查 tavily-adapter 健康
curl http://localhost:8000/health

# 测试搜索接口
curl -X POST http://localhost:8000/search \
     -H "Content-Type: application/json" \
     -d '{"query": "hello world", "max_results": 3}'

# 测试 SearXNG 直连
curl "http://localhost:8999/search?q=test&format=json"
```

---

## 服务端口一览

| 服务 | 地址 | 说明 |
|---|---|---|
| tavily-adapter (API) | http://localhost:8000 | `/search` `/extract` `/research` |
| SearXNG (搜索引擎) | http://localhost:8999 | 可直接访问 Web UI |
| 前端 UI | http://localhost:9762 | Deep-research 界面 |

---

## 日常操作

```bash
# 停止
docker compose down

# 查看适配器日志
docker compose logs -f tavily-adapter

# 重启后重新构建（修改了代码后）
docker compose --env-file .env.hermes up -d --build tavily-adapter

# 运行单元测试（不需要 Docker）
docker compose exec tavily-adapter /opt/hermes/.venv/bin/python -m pytest -q
```

---

## 常见问题

**hermes acp 启动失败 / LLM 调用报错**
- 检查 `.env.hermes` 中的 `OPENAI_API_KEY` 和 `OPENAI_BASE_URL` 是否正确填写
- 确认启动命令带了 `--env-file .env.hermes`

**挂载目录权限错误**
- 确认 `.env.hermes` 中的 `HERMES_UID`/`HERMES_GID` 与宿主机一致

**config.yaml 找不到**
- `docker compose.yaml` 要求 `config.yaml` 存在于项目根目录，必须先执行第二步

**修改了 skills 后不生效**
- 重新执行第五步的同步命令，然后重启容器



```

  ┌────────────────┬───────────────────────────────┬──────────────────────────────────────┐
  │  Render 服务   │             镜像              │                 说明                 │
  ├────────────────┼───────────────────────────────┼──────────────────────────────────────┤
  │ redis          │ valkey/valkey:8-alpine        │ 内部服务，不对外                     │
  ├────────────────┼───────────────────────────────┼──────────────────────────────────────┤
  │ searxng        │ searxng/searxng:latest        │ 需要设 secret_key、SEARXNG_BASE_URL  │
  ├────────────────┼───────────────────────────────┼──────────────────────────────────────┤
  │ tavily-adapter │ walaqi2/searcharvester:latest │ 设 SEARXNG_URL 指向 searxng 服务地址 │
  └────────────────┴───────────────────────────────┴──────────────────────────────────────┘
  ```
SEARXNG_URL = 
  VALKEY_URL redis://red-d8io9o28qa3s73ekq0ag:6379
 SEARXNG_SECRET = a7f3e92b1d456c8f0e3a7b2d9c4f1e86


 完整的 Render 三服务环境变量速查:

  redis 服务: 无需额外环境变量

  searxng 服务:
  SEARXNG_SECRET=a7f3e92b1d456c8f0e3a7b2d9c4f1e86
  VALKEY_URL=redis://red-d8io9o28qa3s73ekq0ag:6379   ← 从 redis 服务 Connect 页复制

  tavily-adapter 服务:
  OPENAI_API_KEY=sk-...
  OPENAI_BASE_URL=https://cc.atai8.cc/v1
  API_KEY=sa-searcharvester-2024
  SEARCH_ENGINES=bing,google
  SEARXNG_URL=https://your-searxng.onrender.com   ← searxng 服务的 External URL