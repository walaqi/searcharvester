# 从零启动

默认你已经有可用的 Docker（Docker Desktop、Colima 或原生 Docker Engine）以及 `docker compose` 命令。

## 1. 克隆仓库

```bash
git clone git@github.com:vakovalskii/searcharvester.git
cd searcharvester
```

## 2. 准备配置

仓库中没有 `config.yaml`（已在 `.gitignore` 中），需要从模板创建：

```bash
cp config.example.yaml config.yaml
```

打开 `config.yaml`，务必修改：

```yaml
server:
  secret_key: "你的随机密钥_至少32个字符"
```

生成密钥：

```bash
# 以下三种任选其一
python3 -c "import secrets; print(secrets.token_hex(32))"
openssl rand -hex 32
head -c 32 /dev/urandom | xxd -p -c 32
```

其余配置 (`adapter.searxng_url`、`adapter.scraper.*`、引擎列表) 可以保持默认值。

## 3. 启动技术栈

```bash
docker compose up -d
```

首次启动需要几分钟（拉取 SearXNG + Valkey 镜像、构建适配器）。后续启动只需几秒。

检查所有服务是否启动成功：

```bash
docker compose ps
```

应看到三个服务均处于 `running` / `healthy` 状态：
- `tavily-adapter`（通过 `/health` 做健康检查）
- `searxng`
- `redis`

## 4. 验证可用性

### SearXNG

浏览器访问：[http://localhost:8999](http://localhost:8999) — 经典的 SearXNG UI。

通过 API：

```bash
curl "http://localhost:8999/search?q=test&format=json" | jq '.results | length'
```

### Tavily Adapter

```bash
# 搜索
curl -X POST http://localhost:8000/search \
  -H "Content-Type: application/json" \
  -d '{"query": "比特币价格", "max_results": 3}' | jq

# 将页面提取为 markdown
curl -X POST http://localhost:8000/extract \
  -H "Content-Type: application/json" \
  -d '{"url":"https://en.wikipedia.org/wiki/Bitcoin","size":"s"}' | jq
```

`/search` 的响应结构示例：

```json
{
  "query": "比特币价格",
  "results": [
    { "url": "...", "title": "...", "content": "...", "score": 0.9, "raw_content": null }
  ],
  "response_time": 1.23,
  "request_id": "..."
}
```

健康检查：

```bash
curl http://localhost:8000/health
# {"status":"ok","service":"searxng-tavily-adapter","version":"2.0.0"}
```

完整端点列表与参数详见 [api.md](api.md)。

## 5. 代码集成

### 方案 A. 使用官方 `tavily-python`

```python
from tavily import TavilyClient

client = TavilyClient(
    api_key="anything",               # 适配器会忽略
    base_url="http://localhost:8000"  # ← 你的适配器
)
response = client.search(query="什么是机器学习", max_results=5, include_raw_content=True)
```

### 方案 B. 本地客户端（无 HTTP）

如果代码与适配器运行在同一宿主机上，又不想走 HTTP：

```python
from simple_tavily_adapter.tavily_client import TavilyClient

client = TavilyClient()  # 读取 config.yaml
response = client.search(query="...", max_results=5, include_raw_content=True)
```

### 方案 C. 裸 HTTP

```python
import requests

r = requests.post("http://localhost:8000/search", json={
    "query": "...",
    "max_results": 5,
    "include_raw_content": True,
})
r.raise_for_status()
data = r.json()
```

## 6. 不用 Docker 开发适配器

如果想快速改适配器代码并启用热重载：

```bash
# SearXNG 继续留在 docker 中（或不动）
cd simple_tavily_adapter
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

开发期间把 `config.yaml` 中的 SearXNG URL 改为宿主机发布端口：

```yaml
adapter:
  searxng_url: "http://localhost:8999"   # 替代 http://searxng:8080
```

然后启动：

```bash
uvicorn main:app --reload --port 8000
```

> 开发完毕后**记得**把 `searxng_url` 改回 `http://searxng:8080`，否则 Docker 容器内适配器找不到 SearXNG（容器内的 `localhost` 指向容器自身）。

## 下一步

- [api.md](api.md) — 完整的请求与响应格式
- [operations.md](operations.md) — 日志、重启、调试、故障排查
- [architecture.md](architecture.md) — 内部是如何工作的


## 部署补充说明
1. Docker 环境变量 SEARCH_ENGINES=google,duckduckgo,brave — 最高优先级，容器运行时随时可改
2. config.yaml 的 adapter.search.default_engines — 作为兜底配置
3. 硬编码 google,duckduckgo,brave — 最后的 fallback
4. 目前API key 是sa-searcharvester-2024，你也可以直接修改 .env.hermes 里的 API_KEY 换成自己想要的值。

如果想自动化，可以用 GitHub Actions：在 .github/workflows/docker-publish.yml 里配置，每次 push 到 main 分支自动 build + push 到 Docker Hub，不需要手动操作。这是生产环境的常见做法

每次代码更新, 需要重新打包上传:
 docker images | grep -E "searcharvester|vakovalskii"

本地构建后镜像名是 ghcr.io/vakovalskii/searcharvester:latest（来自 docker-compose.yaml 的 image: 字段），所以命令是：

docker tag ghcr.io/vakovalskii/searcharvester:latest walaqi2/searcharvester:latest
docker tag ghcr.io/vakovalskii/searcharvester:latest walaqi2/searcharvester:2.2.0

docker push walaqi2/searcharvester:latest
docker push walaqi2/searcharvester:2.2.0


## 带上apikey的tests

 curl -s -X POST http://localhost:8000/search \
    -H "Content-Type: application/json" \
    -H "X-API-Key: sa-searcharvester-2024" \
    -d '{"query":"test","max_results":1}'

