param(
  [string]$PostgresContainer = "postgres_n8n",
  [string]$RedisContainer = "redis_n8n",
  [string]$PostgresDb = "n8n_fila",
  [string]$PostgresUser = "postgres",
  [string]$RedisPassword = "redis"
)

Write-Output "Testando Postgres..."
docker exec $PostgresContainer pg_isready -U $PostgresUser -d $PostgresDb | Write-Output
docker exec $PostgresContainer sh -lc "psql -U $PostgresUser -d $PostgresDb -c 'SELECT 1;'" | Write-Output

Write-Output "Testando Redis..."
docker exec $RedisContainer redis-cli -a $RedisPassword ping | Write-Output
