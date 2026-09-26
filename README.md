# Ibcmd.DevOps

Экспериментальный PowerShell-модуль и архитектурный каркас для управляемой автоматизации `ibcmd` в неоднородном ландшафте 1С:Предприятие.

## Статус

**Публикационный прототип 0.1.0, а не готовый промышленный продукт.** Код предназначен для изучения, рецензирования и испытаний на изолированном стенде. Перед применением сверяйте синтаксис с `ibcmd --help` именно той версии платформы, которая установлена в целевой среде.

## Зачем проект

В корпоративном ландшафте одновременно встречаются файловые и клиент-серверные базы, разные поколения платформы, разные СУБД и смешанные релизные процессы. Проект отделяет:

- низкоуровневое выполнение `ibcmd`;
- типизированные PowerShell-команды;
- описание ландшафта и политики доступа;
- будущий ИИ-слой, который планирует и объясняет, но не получает неограниченный shell-доступ.

## Что реализовано

- `Invoke-Ibcmd` — запуск процесса с массивом аргументов, журналом, контролем exit code и маскированием известных секретов;
- `Test-IbcmdAvailable` и `Get-IbcmdHelp` — preflight и получение справки целевой версии;
- `Export-1CInfobaseImage` — DT-образ через `infobase dump`;
- `Export-1CConfigurationXml` / `Import-1CConfigurationXml`;
- `Save-1CConfigurationFile` — сохранение CF;
- `Install-1CConfigurationFile` — загрузка CF и отдельное, явно включаемое `config apply`;
- `-DryRun`, `SupportsShouldProcess`, `-Confirm` и отдельные ключи для опасных операций.

## Что намеренно не реализовано

- «автоматический ремонт» PROD;
- произвольное выполнение команд по тексту LLM;
- автоматизация `chdbfl`;
- управление сеансами и блокировками;
- универсальная абстракция всех версий CLI `ibcmd`;
- полноценная стратегия резервного копирования.

DT-выгрузка — переносимый образ информационной базы, но не замена штатному резервному копированию средствами СУБД. Официальная документация также требует отсутствия соединений во время `infobase dump`.

## Требования

- PowerShell 7.2+;
- установленная утилита `ibcmd` соответствующей версии платформы 1С;
- права доступа к целевой инфобазе и каталогам;
- отдельный тестовый контур.

PowerShell 7 доступен на Windows, Linux и macOS. Фактическая доступность `ibcmd` зависит от установленной поставки платформы и поддерживаемой ОС.

## Быстрый старт

```powershell
Import-Module ./src/Ibcmd.DevOps/Ibcmd.DevOps.psd1 -Force

Test-IbcmdAvailable -IbcmdPath ibcmd
Get-IbcmdHelp -IbcmdPath ibcmd
Get-IbcmdHelp -IbcmdPath ibcmd -CommandPath @('infobase', 'config')
```

Сначала выполните безопасную имитацию:

```powershell
pwsh ./examples/01-dry-run.ps1 -IbcmdPath /path/to/ibcmd
```

Затем адаптируйте массив `ConnectionArguments` по справке вашей версии. Не копируйте пароли в Git.

## Пример XML-экспорта

```powershell
pwsh ./examples/02-export-xml.ps1 \
  -IbcmdPath /path/to/ibcmd \
  -ConfigPath /secure/1c/demo.yml \
  -OutputDirectory ./artifacts/config-xml
```

## Пример загрузки CF

Без `-Apply` команда только загружает CF. Применение конфигурации БД включается отдельно и требует подтверждения:

```powershell
pwsh ./examples/03-install-cf.ps1 \
  -IbcmdPath /path/to/ibcmd \
  -ConfigPath /secure/1c/test.yml \
  -CfPath ./artifacts/release.cf \
  -Apply
```

`-ForceApply` добавляйте только после проверки поведения на стенде и понимания предупреждений платформы.

## Ландшафт и политика

- `config/landscape.sample.json` — пример реестра баз без реальных секретов;
- `config/policy.sample.json` — минимальная модель разрешений для будущего робота.

JSON выбран намеренно: PowerShell 7 читает его штатно через `ConvertFrom-Json`, без внешнего YAML-модуля.

## Модель ИИ-робота

LLM в предлагаемой архитектуре не запускает shell-команды напрямую. Она:

1. читает очищенную инвентаризацию, регламент и результаты выполнения;
2. формирует типизированный план из разрешённого набора операций;
3. передаёт план детерминированному исполнителю;
4. получает журнал и объясняет результат человеку.

Операции изменения PROD требуют внешнего подтверждения, RBAC, аудита и плана отката.

## Структура

```text
.
├── .github/workflows/powershell-parse.yml
├── config/
│   ├── landscape.sample.json
│   └── policy.sample.json
├── docs/
│   ├── ARTICLE.md
│   └── HOW-TO-USE.md
├── examples/
│   ├── 00-preflight.ps1
│   ├── 01-dry-run.ps1
│   ├── 02-export-xml.ps1
│   └── 03-install-cf.ps1
├── src/Ibcmd.DevOps/
│   ├── Ibcmd.DevOps.psd1
│   └── Ibcmd.DevOps.psm1
├── CHANGELOG.md
├── LICENSE-NOTICE.md
├── README.md
└── SECURITY.md
```

## Проверка перед публикацией

```powershell
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
  "$PWD/src/Ibcmd.DevOps/Ibcmd.DevOps.psm1",
  [ref]$null,
  [ref]$errors
)
$errors
Test-ModuleManifest ./src/Ibcmd.DevOps/Ibcmd.DevOps.psd1
```

## Ограничение ответственности

Код предоставляется для технического исследования. Автор обязан испытать каждую операцию на своей версии платформы и собственной топологии. Наличие `-Confirm` и `-DryRun` снижает риск, но не заменяет регламент эксплуатации.
