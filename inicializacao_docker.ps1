<#
=======================================================
 SCRIPT PARA INICIALIZACAO DO DOCKER E GERACAO DE LOGS
=======================================================
#>

# =================== CONFIGURACOES ===================

# DECLARACAO DAS VARIAVEIS
$VersaoScript = "2.5.3"
$Data = Get-Date -Format "dd-MM-yyyy"
$Diretorio = "C:\Zanthus\Zeus\Docker\Script\Logs"
$ArqLog = Join-Path $Diretorio "$Data.txt"
$MaxLog = 40

# CRIA A PASTA DE LOGS CASO NAO EXISTA
if (!(Test-Path $Diretorio)) {
    New-Item -Path $Diretorio -ItemType Directory -Force | Out-Null
}

# FUNCAO PARA ESCREVER OS LOGS
function Escrever-Log {
    param (
        [string]$Mensagem
    )

    "[" + (Get-Date).ToString("dd-MM-yyyy HH:mm:ss") + "] " + $Mensagem |
        Out-File $ArqLog -Append -Encoding UTF8
}

# SEPARA O LOG POR INICIALIZACAO
$Separador = "——————————————————————————"

if ((Test-Path $ArqLog) -and ((Get-Item $ArqLog).Length -gt 0)) {
    $Separador | Out-File $ArqLog -Append -Encoding UTF8
}

# PUBLICA A VERSAO DO SCRIPT NO LOG
Escrever-Log "..:: Script de inicialização do ambiente Docker | Versão $VersaoScript ::.."

# VERIFICA A PASTA DE LOGS
Escrever-Log "[PROCESSANDO] Analisando a pasta de logs..."
Start-Sleep -Seconds 10
$QtdRemovida = 0
$QtdErros = 0

# REMOVE ARQUIVOS INVALIDOS 
$ArqInvalidos = Get-ChildItem -Path $Diretorio -File |
    Where-Object {
        $_.Name -notmatch '^\d{2}-\d{2}-\d{4}\.txt$'
    }

if ($ArqInvalidos.Count -gt 0) {
	
	Escrever-Log "[AVISO] Identificados arquivos que não correspondem aos logs e serão excluídos."
	Start-Sleep -Seconds 5

    foreach ($Arquivo in $ArqInvalidos) {

        try {
            Remove-Item -Path $Arquivo.FullName -Force -ErrorAction Stop
            Escrever-Log "[SUCESSO] Arquivo removido: $($Arquivo.Name)"
			$QtdRemovida++
        }
        catch {
            Escrever-Log "[ERRO] Não foi possível remover o arquivo: $($Arquivo.Name). Motivo: $($_.Exception.Message)"
			$QtdErros++
        }
    }
}

# REMOVE SUBPASTAS 
$Subpasta = Get-ChildItem -Path $Diretorio -Directory

if ($Subpasta.Count -gt 0) {
	
	Escrever-Log "[AVISO] Encontrado subpasta na pasta de logs. Iniciando exclusão."
	Start-Sleep -Seconds 5
	
	foreach ($Pasta in $Subpasta) {

        try {
            Remove-Item -Path $Pasta.FullName -Recurse -Force -ErrorAction Stop
            Escrever-Log "[SUCESSO] Subpasta removida: $($Pasta.Name)"
			$QtdRemovida++
        }
        catch {
            Escrever-Log "[ERRO] Não foi possível remover a subpasta: $($Pasta.Name). Motivo: $($_.Exception.Message)"
			$QtdErros++
        }
    }
}

# REMOVE ARQUIVOS FUTUROS
$LogsFuturos = Get-ChildItem -Path $Diretorio -Filter "*.txt" -File |
    Where-Object {
        $_.BaseName -match '^\d{2}-\d{2}-\d{4}$' -and
        [datetime]::ParseExact(
            $_.BaseName,
            "dd-MM-yyyy",
            $null
        ) -gt [datetime]::ParseExact(
            $Data,
            "dd-MM-yyyy",
            $null
        )
    } |
    Sort-Object {
        [datetime]::ParseExact(
            $_.BaseName,
            "dd-MM-yyyy",
            $null
        )
    } -Descending

if ($LogsFuturos.Count -gt 0) {

    Escrever-Log "[AVISO] Logs futuros encontrados. Prosseguindo com a remoção."
    Start-Sleep -Seconds 5

    foreach ($Log in $LogsFuturos) {

        try {
            Remove-Item -Path $Log.FullName -Force -ErrorAction Stop
            Escrever-Log "[SUCESSO] Log futuro removido: $($Log.Name)"
			$QtdRemovida++
        }
        catch {
            Escrever-Log "[ERRO] Não foi possível remover o log futuro: $($Log.Name). Motivo: $($_.Exception.Message)"
			$QtdErros++
        }
    }
}

# REMOVE ARQUIVOS ANTIGOS
$Logs = Get-ChildItem -Path $Diretorio -Filter "*.txt" -File |
    Where-Object {
        $_.BaseName -match '^\d{2}-\d{2}-\d{4}$'
    } |
    Sort-Object {
        [datetime]::ParseExact(
            $_.BaseName,
            "dd-MM-yyyy",
            $null
        )
    } -Descending
	

if ($Logs.Count -gt $MaxLog) {

    $LogsAntigos = $Logs | Select-Object -Skip $MaxLog
    Escrever-Log "[AVISO] Logs antigos encontrados. Prosseguindo com a remoção."
	Start-Sleep -Seconds 5

    foreach ($Log in $LogsAntigos) {

        try {
            Remove-Item -Path $Log.FullName -Force -ErrorAction Stop
            Escrever-Log "[SUCESSO] Log antigo removido: $($Log.Name)"
			$QtdRemovida++
        }
        catch {
            Escrever-Log "[ERRO] Não foi possível remover o log: $($Log.Name). Motivo: $($_.Exception.Message)"
			$QtdErros++
        }
    }
}

if ($QtdErros -gt 0) {
    Escrever-Log "[INFO] Análise da pasta de logs concluída. Foram identificadas inconsistências, porém algumas não puderam ser corrigidas."
}
elseif ($QtdRemovida -gt 0) {
    Escrever-Log "[INFO] Análise da pasta de logs concluída. Inconsistências identificadas e corrigidas com sucesso."
}
else {
    Escrever-Log "[INFO] Análise da pasta de logs concluída. Nenhuma inconsistência encontrada."
}


# ==================== VALIDACOES ====================

# == BLOCO 01: WINDOWS 

# VERIFICA VERSAO DO WINDOWS
Escrever-Log "[PROCESSANDO] Identificando a versão do sistema operacional..."
Start-Sleep -Seconds 2

$SO = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty Caption

if ($SO -notmatch 'Server 2022|Server 2025') {
    Escrever-Log "[ERRO] A versão do sistema operacional instalado não é compatível com os requisitos desta tarefa. Encerrando a execução..."
    exit 1
}

Escrever-Log "[INFO] A versão do sistema operacional instalado é compatível com os requisitos desta tarefa..."

# AGUARDA O WINDOWS TERMINAR A INICIALIZACAO
Escrever-Log "[PROCESSANDO] Aguardando o Windows concluir sua inicialização..."
Start-Sleep -Seconds 2

$Tentativa = 0
$MAXTentativa = 36

do {
	
	# VERIFICA SE O SERVICO EVENTLOG ESTA EM EXECUCAO
	$EventLogServico = Get-Service -Name EventLog -ErrorAction SilentlyContinue

	# VERIFICA SE O EXPLORER ESTA EM EXECUCAO
	#$ExplorerProcesso = Get-Process -Name explorer -ErrorAction SilentlyContinue

	# VERIFICA QUANDO OCORREU A ULTIMA INICIALIZACAO DO WINDOWS
	$UltimaSO = Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime

	$DataAtual = Get-Date
	$TempoIni = $DataAtual - $UltimaSO
	
	if ($EventLogServico.Status -eq 'Running' -and
		#$ExplorerProcesso -and
		$TempoIni.TotalSeconds -gt 120) {
			Escrever-Log "[INFO] O Windows finalizou o processo de inicialização."
			break			
		}
		
	Escrever-Log "[AGUARDANDO] O Windows ainda está concluindo a inicialização. Uma nova verificação será realizada..."
	Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
Escrever-Log "[ERRO] Tempo limite atingido (timeout). O Windows não atendeu a todas as condições de inicialização."
exit 1
}	
		
	
# == BLOCO 02: SERVICO HNS

# VALIDA A EXISTENCIA DO SERVICO HNS
Escrever-Log "[PROCESSANDO] Obtendo informações do serviço Host Network Service / Serviço de Rede Host (HNS)..."
Start-Sleep -Seconds 2

$HNSServico = Get-Service -Name HNS -ErrorAction SilentlyContinue

if ($null -eq $HNSServico) {
    Escrever-Log "[ERRO] Não foi localizado o serviço HNS neste sistema."
    exit 1
} 

Escrever-Log "[INFO] O serviço HNS foi localizado no sistema."

# VERIFICA O STATUS DO SERVICO HNS
Escrever-Log "[AGUARDANDO] Obtendo status do serviço HNS..."
Start-Sleep -Seconds 2

$Tentativa = 0
$MAXTentativa = 24

do {
	
    $HNSServico.Refresh()
    $HNSStatus = $HNSServico.Status

    switch ($HNSStatus) {
        "Running" { $HNSStatusBR = "Em execucao" }
        "Stopped" { $HNSStatusBR = "Parado" }
        "Paused"  { $HNSStatusBR = "Pausado" }	
        default   { $HNSStatusBR = $HNSStatus }
    }

    if ($HNSStatus -eq "Running") {
        Escrever-Log "[SUCESSO] Serviço HNS está em execução."
        break
    }
	
    Escrever-Log "[AGUARDANDO] Serviço HNS ainda não está disponível. Estado atual: $HNSStatusBR. Nova verificação..."
    Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
Escrever-Log "[ERRO] Operação interrompida por tempo limite (timeout). Verifique manualmente o serviço HNS."
exit 1
}

# == BLOCO 03: WSL

# VALIDA A EXISTENCIA DO AMBIENTE WSL
Escrever-Log "[PROCESSANDO] Obtendo informações do ambiente WSL..."
Start-Sleep -Seconds 2

if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {

    # VERIFICA SE O AMBIENTE WSL ESTA DISPONIVEL
    wsl --status > $null 2>&1
    $WSLStatus = $LASTEXITCODE

    if ($WSLStatus -eq 0) {

        Escrever-Log "[AGUARDANDO] Ambiente WSL disponível. Iniciando coleta das informações..."
        Start-Sleep -Seconds 3

        # VERIFICA SE EXISTE ALGUMA DISTRIBUICAO INSTALADA
        if ((wsl -l -q).Length -eq 0) {

            Escrever-Log "[ERRO] Nenhuma distribuição Linux instalada no WSL."
            exit 1

        } else {

            # COLETA AS DISTRIBUICOES WSL INSTALADAS
            $DistroLista = wsl -l -v | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" } | ForEach-Object { ($_ -replace "`0", "" -replace '^\s*\*', '').Trim() -replace '\s+', ' ' }
			$UbuntuInstalado = $false

            foreach ($DistribuicaoAtual in $DistroLista) {

                $DistroDados = $DistribuicaoAtual -split '\s+'

                $DistroNome = $DistroDados[0]
                $DistroVersao = $DistroDados[-1]

                Escrever-Log "[INFO] Distribuição instalada: $DistroNome versão do WSL: $DistroVersao."
				
				if ($DistroNome -eq "Ubuntu") {
					$UbuntuInstalado = $true
				}
            }
						
			# VERIFICA SE POSSUI DISTRO UBUNTU
			
			if (-not $UbuntuInstalado) {
				Escrever-Log "[ERRO] Nenhuma distribuição Ubuntu encontrada no WSL. Encerrando o script."
				exit 1
			}
			
			# VERIFICA A DISTRO PADRAO
            $DistroPadrao = wsl -l -v | Select-Object -Skip 1 | ForEach-Object { ($_ -replace "`0", "").Trim() -replace '\s+', ' ' } | Where-Object { $_ -match '^\*' } | ForEach-Object { ($_ -split ' ')[1] }

            if ($DistroPadrao -ne "Ubuntu") {
                Escrever-Log "[INFO] O Ubuntu não está definido como a distribuição padrão do WSL. A distribuição padrão atual é: $DistroPadrao. É necessário ajustar a configuração manualmente."
                exit 1
            }

            Escrever-Log "[INFO] A distribuição padrão configurada no WSL é: $DistroPadrao."

			<#
            # VERIFICA STATUS DISTRO UBUNTU
            Escrever-Log "[AGUARDANDO] Verificando o status da distribuição Ubuntu..."

            $Tentativa = 0
            $MAXTentativa = 24

            do {

                Start-Sleep -Seconds 5

                $StatusUbuntu = wsl -l -v | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" } | ForEach-Object { ($_ -replace "`0", "" -replace '^\s*\*', '').Trim() -replace '\s+', ' ' } | Where-Object { $_ -match "Ubuntu" } | ForEach-Object { $_.Split(' ')[1] }

                if ($StatusUbuntu -eq "Running") {

                    Escrever-Log "[SUCESSO] O Ubuntu está em execução."
                    break

                }

                Escrever-Log "[AGUARDANDO] Ubuntu ainda não está disponível. Estado atual: $StatusUbuntu. Nova verificação..."

                $Tentativa++

            } while ($Tentativa -lt $MAXTentativa)


            if ($Tentativa -ge $MAXTentativa) {

                Escrever-Log "[ERRO] Operação interrompida por tempo limite (timeout). Verifique manualmente o Ubuntu no WSL."
                exit 1

            } #>
        }
    } else {
        Escrever-Log "[ERRO] O ambiente WSL não está disponível. Verifique se ele está instalado, habilitado e configurado corretamente."
        exit 1
    }
} else {
    Escrever-Log "[ERRO] Este Windows não oferece suporte ao WSL ou não possui os recursos necessários habilitados. Verifique a versão do sistema operacional e a configuração do WSL."
    exit 1
}


# == BLOCO 04: SQL

# VALIDA A EXISTENCIA DO SERVICO SQL
Escrever-Log "[PROCESSANDO] Consultando informações do SQL Server..."
Start-Sleep -Seconds 2

$MSSQLServico = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue

if ($null -eq $MSSQLServico) {
    Escrever-Log "[ERRO] Não foram localizados componentes do SQL Server no sistema. Confirme se está instalado corretamente."
    exit 1
}

Escrever-Log "[SUCESSO] Identificado uma instalação do SQL Server no sistema."

# VERIFICA O STATUS DO SERVICO MSSQLSERVER
Escrever-Log "[AGUARDANDO] Verificando o status do serviço SQL Server (MSSQLSERVER)..."
Start-Sleep -Seconds 3

$Tentativa = 0
$MAXTentativa = 24

 do {
	 
	$MSSQLServico.Refresh()
    $MSSQLStatus = $MSSQLServico.Status
	
	if ($MSSQLStatus -eq "Running") {
        Escrever-Log "[SUCESSO] Serviço SQL Server (MSSQLSERVER) está em execução."
        break
    }

    Escrever-Log "[AGUARDANDO] Serviço SQL Server (MSSQLSERVER) ainda não está disponível. Nova verificação em andamento..."
	
    Start-Sleep -Seconds 5
    $Tentativa++
	
} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Tempo limite excedido. O serviço SQL Server (MSSQLSERVER) não entrou em execução."
    exit 1
}

# VERIFICA O STATUS DO SERVICO SQL SERVER AGENT
Escrever-Log "[AGUARDANDO] Verificando o status do serviço SQL Server Agent (MSSQLSERVER)..."
Start-Sleep -Seconds 3

$SQLAgentServico = Get-Service -Name SQLSERVERAGENT -ErrorAction SilentlyContinue

$Tentativa = 0
$MAXTentativa = 24

 do {
	 
	$SQLAgentServico.Refresh()
    $SQLAGENTStatus = $SQLAgentServico.Status
	
	if ($SQLAGENTStatus -eq "Running") {
        Escrever-Log "[SUCESSO] Serviço SQL Server Agent (MSSQLSERVER) está em execução."
        break
    }

    Escrever-Log "[AGUARDANDO] Serviço SQL Server Agent (MSSQLSERVER) ainda não está disponível. Nova verificação em andamento..."
	
    Start-Sleep -Seconds 5
    $Tentativa++
	
} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Tempo limite excedido. O serviço SQL Server Agent (MSSQLSERVER) não entrou em execução."
    exit 1
}	 


# ==================== FLUXO PRINCIPAL ====================

# INICIA O PROCEDIMENTO PARA REINICIAR DO AMBIENTE DO DOCKER
Escrever-Log "[AVISO] Iniciando procedimento de reinicialização do Docker..."
Start-Sleep -Seconds 2


# [ETAPA - 1] DESLIGA COMPLETAMENTE TODAS AS INSTANCIAS DO WSL
Escrever-Log "[AGUARDANDO] Encerrando o WSL (Windows Subsystem for Linux)..."
Start-Sleep -Seconds 5

$RetornoComandoWSL = wsl --shutdown 2>&1
$ExecucaoWSL = $LASTEXITCODE

if ($ExecucaoWSL -ne 0) {
    Escrever-Log "[ERRO] Falha ao encerrar o ambiente WSL. Código: $ExecucaoWSL. Detalhes: $RetornoComandoWSL"
    exit 1
}

# CONSULTA O STATUS DO WSL
$Tentativa = 0
$MAXTentativa = 24

do {

    $StatusWSL = wsl -l -v | Select-Object -Skip 1 | Where-Object { $_.Trim() -ne "" } | ForEach-Object { ($_ -replace "`0", "" -replace '^\s*\*', '').Trim() -replace '\s+', ' ' } | ForEach-Object { $_.Split(' ')[1] }

    if ($StatusWSL -notcontains "Running") {
        Escrever-Log "[SUCESSO] Todas as instâncias do WSL foram encerradas corretamente."
        break
    }

    Escrever-Log "[AGUARDANDO] O WSL ainda possui instâncias ativas. Aguardando o encerramento..."

    Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Operação interrompida por tempo limite (timeout). Finalize manualmente as instâncias ativas do WSL."
    exit 1
}


# [ETAPA - 2] RESETA O HNS E REINICIA A REDE DO WINDOWS
Escrever-Log "[AGUARDANDO] Reiniciando o serviço HNS (Host Network Service)..."
Start-Sleep -Seconds 5

try {

    Restart-Service HNS -Force -ErrorAction Stop

    Escrever-Log "[INFO] O Serviço HNS foi reiniciado. Aguardando estabilização..."
    Start-Sleep -Seconds 3

} catch {
    Escrever-Log "[ERRO] Falha ao reiniciar o serviço HNS: $($_.Exception.Message)"
    exit 1
}

# VALIDA SE O HNS ESTA OPERACIONAL
Escrever-Log "[PROCESSANDO] Validando disponibilidade do serviço HNS..."

$Tentativa = 0
$MAXTentativa = 24

do {    

    $HNSStatus = (Get-Service -Name HNS).Status

    if ($HNSStatus -eq "Running") {
        Escrever-Log "[SUCESSO] O serviço HNS foi reiniciado e está operando normalmente."
        break
    }

    Escrever-Log "[AGUARDANDO] Serviço HNS ainda não está disponível. Realizando nova tentativa de verificação..."

	Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)


if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Falha na inicialização do serviço HNS após reinício. Verificação manual necessária."
    exit 1
}


# [ETAPA - 3] INICIA O SERVICO DOCKER NA DISTRIBUICAO WSL
Escrever-Log "[AGUARDANDO] Iniciando o serviço do Docker..."
Start-Sleep -Seconds 5

# INICIA O DOCKER USANDO SYSTEMD OU SERVICE, CONFORME O AMBIENTE.
wsl -d Ubuntu -u root test -d /run/systemd/system
$ExecucaoSystemd = $LASTEXITCODE

if ($ExecucaoSystemd -eq 0) {

    Escrever-Log "[INFO] Detectado que a distribuição utiliza systemd. Iniciando o serviço do Docker via systemctl (docker.service)..."
    $RetornoDocker = wsl -d Ubuntu -u root systemctl start docker 2>&1
    $ExecucaoDocker = $LASTEXITCODE
} else {

    Escrever-Log "[INFO] Detectado que a distribuição utiliza init/service. Iniciando o serviço do Docker pelo script de serviço (service docker start)..."
    $RetornoDocker = wsl -d Ubuntu -u root service docker start 2>&1
    $ExecucaoDocker = $LASTEXITCODE
}

if ($ExecucaoDocker -ne 0) {
	
	$RetornoDocker = ($RetornoDocker | Out-String).Trim()
    Escrever-Log "[ERRO] Falha ao iniciar o serviço do Docker. Verificação manual necessária. Código: $ExecucaoDocker. Detalhes: $RetornoDocker"
    exit 1
}

# VALIDA SE O SERVICO DO DOCKER ESTA OPERACIONAL
Escrever-Log "[AGUARDANDO] Validando disponibilidade do serviço do Docker..."

$Tentativa = 0
$MAXTentativa = 24

do {  
	
	$StatusDocker = wsl -d Ubuntu -u root docker info 2>&1
	$CodStatusDocker = $LASTEXITCODE
		
	if ($CodStatusDocker -eq 0) {
        Escrever-Log "[SUCESSO] Docker está respondendo corretamente."
		break
    } 

    Escrever-Log "[AGUARDANDO] Docker ainda não está disponível. Realizando nova tentativa de verificação..."
        
	Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)


if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Falha na inicialização do serviço do Docker. Verificação manual necessária."
    exit 1
}

# [ETAPA - 4] VALIDA, FINALIZA E INICIA OS CONTAINERS DO AMBIENTE

# VERIFICA SE POSSUI ALGUM CONTAINERS EM EXECUCAO
Escrever-Log "[PROCESSANDO] Verificando se há containers em execução..."
Start-Sleep -Seconds 3

$Tentativa = 0
$MAXTentativa = 24
	
do {

	$StatusContainers = wsl -d Ubuntu -u root sh -c 'docker ps --filter "status=running" --format "{{.Names}}"'

	if (-not [string]::IsNullOrWhiteSpace($StatusContainers)){
    	Escrever-Log "[PROCESSANDO] Identificados containers em execução, iniciando o procedimento de finalização..."
		wsl -d Ubuntu -u root sh -c 'docker ps -q --filter "status=running" | xargs -r docker stop -t 5'
	
	} else {
    	Escrever-Log "[INFO] Nenhum contêiner em execução foi encontrado."
		break
	}

	Escrever-Log "[AGUARDANDO] Preparando para verificar novamente se há containers em execução..."
		
	Start-Sleep -Seconds 5
    $Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {
    Escrever-Log "[ERRO] Falha na finalização dos containers em execução. Verificação manual necessária."
    exit 1
}


# INICIA OS CONTAINERS
Escrever-Log "[AGUARDANDO] Iniciando os containers..."
Start-Sleep -Seconds 3

# INICIA O CONTAINER REDIS/VALKEY
Escrever-Log "[AGUARDANDO] Iniciando o container Redis/Valkey..."
Start-Sleep -Seconds 2


$Tentativa = 0
$MAXTentativa = 24
	
do {
								
	#$ContainerRedis = wsl -d Ubuntu -u root sh -c 'cd /docker/docker_redis && docker compose up -d' 2>&1
	$ContainerRedis = wsl -d Ubuntu -u root sh -c 'docker start docker_redis-redis-1' 2>&1
	
	Start-Sleep -Seconds 10
    
	#$StatusRedis = wsl -d Ubuntu -u root sh -c 'docker ps --filter "name=redis" --format "{{.Names}}"'
	$StatusRedis = wsl -d Ubuntu -u root sh -c 'docker ps --filter "status=running" --filter "name=redis" --format "{{.Names}}"'
	
	if (-not [string]::IsNullOrWhiteSpace($StatusRedis)){
		
		Escrever-Log "[SUCESSO] O container Redis/Valkey foi iniciando."
		break
	}
		
	$Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {

    Escrever-Log "[ERRO] Falha na inicialização do container Redis/Valkey. Verificação manual necessária. Mensagem: $ContainerRedis."
    exit 1

}

# INICIA O CONTAINER MIRAGE
Escrever-Log "[AGUARDANDO] Iniciando o container Mirage..."
Start-Sleep -Seconds 2

$Tentativa = 0
$MAXTentativa = 24
	
do {
	
	#$ContainerMirage = wsl -d Ubuntu -u root sh -c 'cd /docker/docker_mirage && docker compose up -d' 2>&1
	$ContainerMirage = wsl -d Ubuntu -u root sh -c 'docker start docker_mirage-mirage-1' 2>&1
	
	Start-Sleep -Seconds 10
    
	#$StatusMirage = wsl -d Ubuntu -u root sh -c 'docker ps --filter "name=mirage" --format "{{.Names}}"'
	$StatusMirage = wsl -d Ubuntu -u root sh -c 'docker ps --filter "status=running" --filter "name=mirage" --format "{{.Names}}"'
	
	if (-not [string]::IsNullOrWhiteSpace($StatusMirage)){
		
		Escrever-Log "[SUCESSO] O container Mirage foi iniciando."
		break
	}
		
	$Tentativa++

} while ($Tentativa -lt $MAXTentativa)

if ($Tentativa -ge $MAXTentativa) {

    Escrever-Log "[ERRO] Falha na inicialização do container Mirage. Verificação manual necessária. Mensagem: $ContainerMirage."
    exit 1
}


# [ETAPA - 5] MAPEAMENTO DA REDE
Escrever-Log "[PROCESSANDO] Configurando os parâmetros de rede..."
Start-Sleep -Seconds 2

# OBTEM O ENDEREÇO IP DO WSL
Escrever-Log "[PROCESSANDO] Identificando o endereço IP do ambiente WSL..."
Start-Sleep -Seconds 2

$WSLIP = (wsl hostname -I 2>$null).Trim().Split(' ')[0]

if ($LASTEXITCODE -ne 0 -or -not $WSLIP) {
    Escrever-Log "[ERRO] Falha ao obter o IP do WSL."
    exit 1
} 

Escrever-Log "[SUCESSO] IP do WSL obtido: $WSLIP"
Start-Sleep -Seconds 1

# EXCLUI REDIRECIONAMENTO DE PORTAS
Escrever-Log "[PROCESSANDO] Preparando o ambiente para configurar os redirecionamentos de portas..."
Start-Sleep -Seconds 2

# PORTA 80
Escrever-Log "[AGUARDANDO] Verificando a existência de uma regra de redirecionamento para a porta 80..."
$Regra = netsh interface portproxy show v4tov4

if ($Regra -match "0\.0\.0\.0\s+80") {
	Escrever-Log "[AVISO] Encontrada regra para a porta 80. Iniciando a remoção..."
    netsh interface portproxy delete v4tov4 listenport=80 listenaddress=0.0.0.0 2>$null | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Escrever-Log "[ERRO] Falha ao remover a regra da porta 80."
    }
    
	Escrever-Log "[SUCESSO] Regra de redirecionamento da porta 80 removida com sucesso."
}
else {
    Escrever-Log "[AVISO] Nenhuma regra de redirecionamento correspondente à porta 80 foi encontrada. Nenhuma ação necessária."
}

# PORTA 6379
Escrever-Log "[AGUARDANDO] Verificando a existência de uma regra de redirecionamento para a porta 6379..."
$Regra = netsh interface portproxy show v4tov4

if ($Regra -match "0\.0\.0\.0\s+6379") {
	Escrever-Log "[AVISO] Encontrada regra para a porta 6379. Iniciando a remoção..."
    netsh interface portproxy delete v4tov4 listenport=6379 listenaddress=0.0.0.0 2>$null | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Escrever-Log "[ERRO] Falha ao remover a regra da porta 6379."
    }
    
	Escrever-Log "[SUCESSO] Regra de redirecionamento da porta 6379 removida com sucesso."
}
else {
    Escrever-Log "[AVISO] Nenhuma regra de redirecionamento correspondente à porta 6379 foi encontrada. Nenhuma ação necessária."
}

# CRIA REDIRECIONAMENTO DE PORTA
Escrever-Log "[PROCESSANDO] Iniciando a criação do redirecionamento das portas para o WSL..."
Start-Sleep -Seconds 2

# PORTA 80
Escrever-Log "[AGUARDANDO] Iniciando a criação do redirecionamento da porta 80 para o WSL."
netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=80 connectaddress=$WSLIP 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    Escrever-Log "[ERRO] Falha ao configurar o redirecionamento da porta 80 para o WSL."
}
else {
    Escrever-Log "[SUCESSO] Redirecionamento da porta 80 para o WSL configurado com sucesso."
}

# PORTA 6379
Escrever-Log "[AGUARDANDO] Iniciando a criação do redirecionamento da porta 6379 para o WSL."
netsh interface portproxy add v4tov4 listenport=6379 listenaddress=0.0.0.0 connectport=6379 connectaddress=$WSLIP 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    Escrever-Log "[ERRO] Falha ao configurar o redirecionamento da porta 6379 para o WSL."
}
else {
    Escrever-Log "[SUCESSO] Redirecionamento da porta 6379 para o WSL configurado com sucesso."
}

# REGRA NO FIREWALL DO WINDOWS 
Escrever-Log "[PROCESSANDO] Validando o ambiente para aplicação das regras de firewall..."
Start-Sleep -Seconds 2

# EXCLUI A REGRA DOCKER_WSL_PORT_80 NO FIREWALL DO WINDOWS
Escrever-Log "[AGUARDANDO] Checando a existência da regra 'Docker_WSL_Port_80' no Firewall do Windows..."
Start-Sleep -Seconds 2

try {
    $Firewall = Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.DisplayName -eq "Docker_WSL_Port_80" }

    if ($null -ne $Firewall) {
        Escrever-Log "[AVISO] Encontrada a regra 'Docker_WSL_Port_80' na configuração do Firewall. Iniciando a remoção..."
		Start-Sleep -Seconds 2
		
		netsh advfirewall firewall delete rule name="Docker_WSL_Port_80" 2>$null | Out-Null

		if ($LASTEXITCODE -ne 0) {
			Escrever-Log "[ERRO] Não foi possível excluir a regra 'Docker_WSL_Port_80'."
		}
		else {
			Escrever-Log "[SUCESSO] A regra 'Docker_WSL_Port_80' foi excluída com sucesso."
		}
    }
    else {
        Escrever-Log "[AVISO] A regra 'Docker_WSL_Port_80' não consta na configuração do Firewall."
    }
}
catch {
    Escrever-Log "[ERRO] Ocorreu um erro ao consultar a regra 'Docker_WSL_Port_80' no Firewall."
    exit 1
}

# EXCLUI A REGRA DOCKER_WSL_PORT_6379 NO FIREWALL DO WINDOWS
Escrever-Log "[AGUARDANDO] Checando a existência da regra 'Docker_WSL_Port_6379' no Firewall do Windows..."
Start-Sleep -Seconds 2

try {
    $Firewall = Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.DisplayName -eq "Docker_WSL_Port_6379" }

    if ($null -ne $Firewall) {
        Escrever-Log "[AVISO] Encontrada a regra 'Docker_WSL_Port_6379' na configuração do Firewall. Iniciando a remoção..."
		Start-Sleep -Seconds 2
		
		netsh advfirewall firewall delete rule name="Docker_WSL_Port_6379" 2>$null | Out-Null

		if ($LASTEXITCODE -ne 0) {
			Escrever-Log "[ERRO] Não foi possível excluir a regra 'Docker_WSL_Port_6379'."
		}
		else {
			Escrever-Log "[SUCESSO] A regra 'Docker_WSL_Port_6379' foi excluída com sucesso."
		}
    }
    else {
        Escrever-Log "[AVISO] A regra 'Docker_WSL_Port_6379' não consta na configuração do Firewall."
    }
}
catch {
    Escrever-Log "[ERRO] Ocorreu um erro ao consultar a regra 'Docker_WSL_Port_6379' no Firewall."
    exit 1
}

# CRIA REGRA NO FIREWALL DO WINDOWS 
Escrever-Log "[PROCESSANDO] Iniciando a configuração das regras do Firewall do Windows..."
Start-Sleep -Seconds 2

# CRIA REGRA DOCKER_WSL_PORT_80 NO FIREWALL
Escrever-Log "[AGUARDANDO] Adicionando a regra 'Docker_WSL_Port_80' ao Firewall..."
netsh advfirewall firewall add rule name="Docker_WSL_Port_80" dir=in action=allow protocol=TCP localport=80 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    Escrever-Log "[ERRO] Não foi possível criar a regra 'Docker_WSL_Port_80' no Firewall do Windows."
}
else {
    Escrever-Log "[SUCESSO] Regra 'Docker_WSL_Port_80' adicionada com sucesso ao Firewall."	
}

# CRIA REGRA DOCKER_WSL_PORT_6379 NO FIREWALL
Escrever-Log "[AGUARDANDO] Adicionando a regra 'Docker_WSL_Port_6379' ao Firewall..."
netsh advfirewall firewall add rule name="Docker_WSL_Port_6379" dir=in action=allow protocol=TCP localport=6379 2>$null | Out-Null

if ($LASTEXITCODE -ne 0) {
    Escrever-Log "[ERRO] Não foi possível criar a regra 'Docker_WSL_Port_6379' no Firewall do Windows."
}
else {
    Escrever-Log "[SUCESSO] Regra 'Docker_WSL_Port_6379' adicionada com sucesso ao Firewall."	
}

# VALIDACAO DO FUNCIONAMENTO DAS APLICACOES
Escrever-Log "[PROCESSANDO] Validando a disponibilidade das aplicações..."
Start-Sleep -Seconds 2

# VERIFICANDO OS CONTAINERS
Escrever-Log "[AGUARDANDO] Coletando status dos containers..."
Start-Sleep -Seconds 3

# CAPTURA STATUS DO CONTAINER MIRAGE
$MirageStatus = wsl -u root docker ps --filter "name=docker_mirage-mirage-1" --format "{{.Status}}" 

if ($MirageStatus) {
    $MirageStatus = $MirageStatus | ForEach-Object {
        $_ -replace "^Up", "em execução há " `
		   -replace " Less than a seconds?", " menos de um segundo" `
           -replace " hours?", " hora(s)" `
           -replace " minutes?", " minuto(s)" `
           -replace " seconds?", " segundo(s)" `
           -replace " days?", " dia(s)"
    }
}
else {
    $MirageStatus = "NAO_IDENTIFICADO"
}

# CAPTURA STATUS DO CONTAINER REDIS
$ValkeyStatus = wsl -u root docker ps --filter "name=docker_redis-redis-1" --format "{{.Status}}"

if ($ValkeyStatus) {
    $ValkeyStatus = $ValkeyStatus | ForEach-Object {
        $_ -replace "^Up", "em execução há " `
		   -replace " Less than a seconds?", " menos de um segundo" `
           -replace " hours?", " hora(s)" `
           -replace " minutes?", " minuto(s)" `
           -replace " seconds?", " segundo(s)" `
           -replace " days?", " dia(s)"
    }
}
else {
    $ValkeyStatus = "NAO_IDENTIFICADO"
}

# COLETA DA DATA DE CRIACAO DO CONTAINER MIRAGE

$MirageCriacao = wsl -u root docker ps --filter "name=docker_mirage-mirage-1" --format "{{.CreatedAt}}"

if ($MirageCriacao) {
    try {
        $MirageCriacao = [DateTimeOffset]::ParseExact(
            ($MirageCriacao.Trim() -replace ' -03$', ''),
            "yyyy-MM-dd HH:mm:ss zzz",
            [System.Globalization.CultureInfo]::InvariantCulture
        ).ToString(
            "dd/MM/yyyy HH:mm:ss",
            [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
        )

        $MirageCriacao = "$MirageCriacao"
    }
    catch {
		Escrever-Log "[AVISO] Não foi possível converter a data para o formato esperado."
    }
}
else {
    $MirageCriacao = "NAO_IDENTIFICADO"
}

# COLETA DA DATA DE CRIACAO DO CONTAINER REDIS

$RedisCriacao = wsl -u root docker ps --filter "name=docker_redis-redis-1" --format "{{.CreatedAt}}"

if ($RedisCriacao) {
    try {
        $RedisCriacao = [DateTimeOffset]::ParseExact(
            ($RedisCriacao.Trim() -replace ' -03$', ''),
            "yyyy-MM-dd HH:mm:ss zzz",
            [System.Globalization.CultureInfo]::InvariantCulture
        ).ToString(
            "dd/MM/yyyy HH:mm:ss",
            [System.Globalization.CultureInfo]::GetCultureInfo("pt-BR")
        )

        $RedisCriacao = "$RedisCriacao"
    }
    catch {
        Escrever-Log "[AVISO] Não foi possível converter a data para o formato esperado."
    }
}
else {
    $RedisCriacao = "NAO_IDENTIFICADO"
}

# EXIBE AS INFORMACOES DOS CONTAINERS
if ($MirageStatus -ne "NAO_IDENTIFICADO" -and $MirageCriacao -ne "NAO_IDENTIFICADO") {
	Escrever-Log "[SUCESSO] O container Mirage foi criado em $MirageCriacao e possui o status $MirageStatus." 		
}
else{
	Escrever-Log "[ERRO] Não foi possível obter informações do container Mirage, que pode estar parado ou indisponível."
}

if ($ValkeyStatus -ne "NAO_IDENTIFICADO" -and $RedisCriacao -ne "NAO_IDENTIFICADO") {
	Escrever-Log "[SUCESSO] O container Redis foi criado em $RedisCriacao e possui o status $ValkeyStatus."
}
else{
	Escrever-Log "[ERRO] Não foi possível obter informações do container Redis, que pode estar parado ou indisponível."	
}

# TESTE DE CONEXOES
Escrever-Log "[PROCESSANDO] Iniciando os testes de conectividade dos serviços..."
Start-Sleep -Seconds 2

# VERIFICA SE A PORTA 80 LOCAL ESTA DISPONIVEL PARA CONEXOES HTTP
Escrever-Log "[AGUARDANDO] Verificando a disponibilidade do serviço Web Mirage na porta 80 (HTTP)..."
Start-Sleep -Seconds 3

$HTTPTeste = Invoke-WebRequest -Uri "http://127.0.0.1:80" -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue

if ($HTTPTeste.StatusCode -eq 200) {
	Escrever-Log "[SUCESSO] Serviço Web Mirage acessível via HTTP na porta 80."
} else {        
	Escrever-Log "[ERRO] Serviço Web Mirage indisponível ou sem resposta HTTP válida na porta 80."
}

# VERIFICA SE E POSSIVEL ESTABELECER UMA CONEXAO TCP COM A PORTA 6379
Escrever-Log "[AGUARDANDO] Verificando a conectividade TCP com o serviço Valkey/Redis na porta 6379..."
Start-Sleep -Seconds 3

$TCPTeste = Test-NetConnection -ComputerName "127.0.0.1" -Port 6379

if ($TCPTeste.TcpTestSucceeded) {
	Escrever-Log "[SUCESSO] Serviço Valkey/Redis acessível via TCP na porta 6379."
} else {
	Escrever-Log "[ERRO] Não foi possível estabelecer conexão TCP com o Valkey/Redis na porta 6379."
}

# ABRE UMA NOVA JANELA DO POWERSHELL E EXECUTA O WSL
Escrever-Log "[PROCESSANDO] Iniciando uma nova janela interativa do WSL...."
Start-Sleep -Seconds 2

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "wsl"
    
	
# ==================== FIM ====================
Escrever-Log "[INFO] O processo de inicialização do Docker foi finalizado."
exit 0
