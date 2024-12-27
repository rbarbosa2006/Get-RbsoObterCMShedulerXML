#Scripts para obter arquivo quartz_jobs do aplicativo CMSheduler com o PowerShell - Rogério Barbosa.
#Declaração da variáveis do Script
$xmlFilePath = "C:\CMFlexScheduler\quartz_jobs.xml"

<# Funcao para extrair informações do arquivo quartz_jobs.xml #>
Function Read-RbsoObterQuartzJobs{
    Param([string]$sAux)

    # Load XML from a file
    [xml]$xmlDocument = Get-Content -Path $sAux

    $result = foreach($i in $xmlDocument.'job-scheduling-data'.schedule.job) {
        $out = [ordered]@{}
        foreach($prop in $i.ChildNodes){ 
            if(!($prop.Name -eq "job-data-map")){ $out[$prop.Name] = $prop.'#text' }
            else{ $out[$prop.Name] = foreach($u in $prop.entry) { foreach($p in $u.ChildNodes){ if(!($p.Name -eq "key")){ $p.'#text' } } } }
        }
        $out['repeat-interval'] = $xmlDocument.'job-scheduling-data'.schedule.trigger.simple | Where-Object { $_.'job-name' -eq $out.name } | Select-Object -ExpandProperty repeat-interval
        $out['projeto'] = $out.'job-data-map'[0].Split('/')[3]
        [pscustomobject]$out
    }
    return $result
}

<# Funcao para selecionar projetos para exibir o serviço #>
Function Get-RbsoSelecionarProjeto{
    Param([PSCustomObject]$oAux)
    $aValIndiceEspaco = $aValIndiceLetra = $aValidaIndice = $aValIndiceDuplicado = $aMenuIndice = $aAuxSolution = @() # Variáveis array que serão utilizadas ao longo do processo
    do{
        $cSimNao = 'n'
        Write-Host "==============================="
        Write-Host "######## MENU PROJETOS ########"
        Write-Host "==============================="
        Write-Host "[ 00 ] Todos"
        1..$($oAux.Length) | ForEach-Object -process { Write-Host "[ $('{0:d2}' -f $_) ] $($oAux[[convert]::ToInt32($_, 10) - 1])"}

        Write-Host "`nEscolha o(s) item(ns) separando por vírgula.Ex: 2,5,8,..." -NoNewline
        Write-Host " ou digite" -NoNewline
        Write-Host " [0]" -ForegroundColor Magenta -NoNewline
        Write-Host " para selecionar todos: "  -NoNewline
        $aValIndiceEspaco += (Read-Host).Split(',')

        if(!$aValIndiceEspaco.Contains('0')){
            #Caso existam virgulas sem indice, este trecho elimina. Ex: 2,,5,,7 = 2 5 7
            $aValIndiceLetra += $aValIndiceEspaco | ForEach-Object {if(![string]::IsNullOrWhiteSpace($_)){$_}}

            #Caso existam letras ao invés de números, este trecho elimina. Ex: n,,2,3,n = 2 3
            $aValidaIndice += $aValIndiceLetra | ForEach-Object {if(([regex] '^(\d+)$').IsMatch($_)){$_}}

            #Caso selecione um índice de menu que não exista, este trecho elimina. Ex: Menu [0...60] - Escolha o(s) Módulo(s): n,,v,2,3,n,99 => 2 3
            $aValIndiceDuplicado += $aValidaIndice | ForEach-Object {if($oAux.Length -ge [convert]::ToInt32($_, 10)){$_}}

            #Caso existam duplicidades, este trecho elimina e reorganiza.
            $aMenuIndice = $aValIndiceDuplicado | Sort-Object -Unique

            if(![string]::IsNullOrEmpty($aMenuIndice)){
                Write-Host `n
                $aMenuIndice | ForEach-Object {Write-Host "Você escolheu: " -NoNewline; Write-Host "$($oAux[[convert]::ToInt32($_, 10) - 1])" -ForegroundColor Cyan;$aAuxSolution += $oAux[[convert]::ToInt32($_, 10) - 1]}
                $cSimNao = 's'
            }
            else{ Write-Host "[INFORMATIVO] Opção invalida!" -ForegroundColor Yellow }
        }
        else{
            Write-Host "`nVocê escolheu " -NoNewline
            Write-Host "Todos os itens" -ForegroundColor Cyan
            $aAuxSolution = $oAux
            $cSimNao = 's'
        }
        if('s'.Equals($cSimNao)){ return $aAuxSolution }
        else{ $aValIndiceEspaco = $aValIndiceLetra = $aValidaIndice = $aValIndiceDuplicado = $aMenuIndice = $aAuxSolution = @() }

    }while('n'.Equals($cSimNao))
}

<# Funcao para converter o intervalo em milisegundos #>
Function Measure-RbsoFormatMilliseconds{
    Param([string]$sAux)

    $nAuxDias = [int][Math]::Floor($sAux / 86400000)
    $nAuxHoras = [int][Math]::Floor($sAux / 3600000) % 24
    $nAuxMinutos = [int][Math]::Floor($sAux / 60000) % 60
    $nAuxSegundos = [int][Math]::Floor($sAux / 1000) % 60
    $nAuxMillisRemaining = [int]$sAux % 1000

    return "$('{0:d2}' -f $nAuxDias) dias $('{0:d2}' -f $nAuxHoras) horas $('{0:d2}' -f $nAuxMinutos) minutos $('{0:d2}' -f $nAuxSegundos) segundos."
}

Clear-Host
Write-Host "================================"
Write-Host "##### DASHBOARD CMSCHEDULER ####"
Write-Host "================================"
if(Test-Path -Path $xmlFilePath){ $oAuxQuartz = Read-RbsoObterQuartzJobs -sAux $xmlFilePath }
else{ 
    Write-Host "`nError Message: Não é possível localizar o caminho '$($xmlFilePath)'`n" -ForegroundColor Yellow 
    break
}
Write-Host "Foram encontrados $($oAuxQuartz.Count) serviços em execução no aplicativo CMCsheduler`n"

Write-Host "Agrupados por projeto:"
$oAuxQuartz | Group-Object -Property projeto -NoElement | Format-Table -AutoSize -Wrap

$oAuxProjeto = Get-RbsoSelecionarProjeto -oAux (($oAuxQuartz | Sort-Object -Property projeto -Unique).projeto)

$oAuxProjeto | ForEach-Object{
    $sAux = $_
    Write-Host "`n `t `t==== $sAux ===="
    $oAuxQuartz | ForEach-Object { if($sAux -eq $_.projeto) { Write-Host "`nServiço..: $($_.'job-data-map'[0])`n`nTenants..: $($_.'job-data-map'[1])`n`nIntervalo: $($_.'repeat-interval') Milissegundos => $(Measure-RbsoFormatMilliseconds -sAux $($_.'repeat-interval'))`n" } }
}
