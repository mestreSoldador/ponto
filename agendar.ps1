# Cria (ou recria) as tarefas de ponto no Agendador de Tarefas do Windows.
#
#   Agendar:  powershell -ExecutionPolicy Bypass -File .\agendar.ps1
#   Remover:  powershell -ExecutionPolicy Bypass -File .\agendar.ps1 -Remover
#
# Cada marcação dispara no horário de início e o próprio Windows sorteia um atraso
# aleatório de 0 até $JanelaMinutos minutos (ex: 13:00 + até 10 min = entre 13:00 e 13:10).

param([switch]$Remover)

# ===== CONFIGURAÇÃO =====
$JanelaMinutos = 10

# Dias da semana de cada escala
$Escalas = @{
    Normal = 'Monday', 'Tuesday', 'Friday'
    QuaQui = 'Wednesday', 'Thursday'
}

# Horário de INÍCIO da janela de cada marcação, por escala
$Marcacoes = @(
    @{ Nome = '1 - Entrada';      Normal = '07:50'; QuaQui = '07:00' }   # 07:50-08:00 | 07:00-07:10
    @{ Nome = '2 - Saida almoco'; Normal = '12:00'; QuaQui = '12:00' }   # 12:00-12:10 | 12:00-12:10
    @{ Nome = '3 - Volta almoco'; Normal = '13:00'; QuaQui = '13:05' }   # 13:00-13:10 | 13:05-13:15
    @{ Nome = '4 - Saida';        Normal = '18:00'; QuaQui = '17:00' }   # 18:00-18:10 | 17:00-17:10
)
# ========================

$PastaTarefas = '\EasyMOB Ponto\'
$Script = Join-Path $PSScriptRoot 'registrar-ponto.cmd'

# Remove as tarefas antigas desta pasta
Get-ScheduledTask -TaskPath $PastaTarefas -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false

if ($Remover) {
    Write-Host 'Tarefas de ponto removidas.'
    return
}

$Acao = New-ScheduledTaskAction -Execute "`"$Script`"" -WorkingDirectory $PSScriptRoot

$Config = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

foreach ($m in $Marcacoes) {
    # Uma tarefa por marcação, com um gatilho para cada escala
    $Gatilhos = foreach ($escala in $Escalas.Keys) {
        New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Escalas[$escala] -At $m[$escala] `
            -RandomDelay (New-TimeSpan -Minutes $JanelaMinutos)
    }

    Register-ScheduledTask -TaskPath $PastaTarefas -TaskName $m.Nome `
        -Action $Acao -Trigger $Gatilhos -Settings $Config `
        -Description "Registra o ponto no EasyMOB (janela de $JanelaMinutos min)" | Out-Null

    Write-Host ("Agendado: {0,-18} seg/ter/sex {1}  |  qua/qui {2}  (+ ate {3} min)" -f $m.Nome, $m.Normal, $m.QuaQui, $JanelaMinutos)
}

Write-Host ''
Write-Host "Pronto. Veja/edite em: Agendador de Tarefas > Biblioteca > $($PastaTarefas.Trim('\'))"
