# Mostra se as tarefas de ponto estao ativas, a proxima execucao e o resultado das ultimas.
#   npm run status

$PastaTarefas = '\EasyMOB Ponto\'
$Log = Join-Path $PSScriptRoot 'logs\ponto.log'
$ptBR = [Globalization.CultureInfo]'pt-BR'

function Formatar-Data($d) {
    if (-not $d -or $d.Year -lt 2000) { return '-' }
    return $d.ToString('ddd dd/MM HH:mm', $ptBR)
}

function Formatar-Resultado($codigo, $ultima) {
    if (-not $ultima -or $ultima.Year -lt 2000) { return 'nunca rodou' }
    switch ($codigo) {
        0       { 'OK' }
        1       { 'ERRO (ver logs)' }
        2       { 'ATENCAO (ver print)' }
        267009  { 'rodando agora' }
        267011  { 'nunca rodou' }
        default { "codigo $codigo" }
    }
}

$tarefas = @(Get-ScheduledTask -TaskPath $PastaTarefas -ErrorAction SilentlyContinue)

Write-Host ''
if ($tarefas.Count -eq 0) {
    Write-Host 'Ponto automatico: DESATIVADO (nenhuma tarefa agendada)' -ForegroundColor Yellow
    Write-Host 'Para ativar: npm run agendar'
} else {
    $linhas = foreach ($t in $tarefas) {
        $info = $t | Get-ScheduledTaskInfo
        [pscustomobject]@{
            'Marcacao'          = $t.TaskName
            'Estado'            = if ($t.State -eq 'Disabled') { 'desabilitada' } else { 'ativa' }
            'Proxima janela'    = Formatar-Data $info.NextRunTime
            'Ultima execucao'   = Formatar-Data $info.LastRunTime
            'Resultado'         = Formatar-Resultado $info.LastTaskResult $info.LastRunTime
        }
    }

    $ativas = @($tarefas | Where-Object State -ne 'Disabled').Count
    $cor = if ($ativas -eq $tarefas.Count) { 'Green' } else { 'Yellow' }
    Write-Host "Ponto automatico: ATIVO ($ativas de $($tarefas.Count) tarefas)" -ForegroundColor $cor
    Write-Host '"Proxima janela" = inicio da janela; o ponto cai num horario aleatorio nos 10 min seguintes.'
    $linhas | Sort-Object Marcacao | Format-Table -AutoSize | Out-String | Write-Host

    $proxima = $tarefas | Get-ScheduledTaskInfo | Where-Object { $_.NextRunTime } |
        Sort-Object NextRunTime | Select-Object -First 1
    if ($proxima) {
        Write-Host ("Proximo ponto: {0} ({1})" -f (Formatar-Data $proxima.NextRunTime), $proxima.TaskName) -ForegroundColor Cyan
    }
}

# Ultimos resultados registrados no log
if (Test-Path $Log) {
    $resultados = Get-Content $Log -Encoding UTF8 |
        Where-Object { $_ -match 'sucesso!|ERRO|ATEN|Modo teste:' -and $_ -notmatch 'Login realizado' } |
        Select-Object -Last 5
    if ($resultados) {
        Write-Host ''
        Write-Host 'Ultimos registros do log:'
        $resultados | ForEach-Object { Write-Host "  $_" }
    }
}
Write-Host ''
