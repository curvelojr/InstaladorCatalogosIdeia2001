# 1. AUTO-ELEVAÇÃO PARA ADMINISTRADOR
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2. FORÇAR CODIFICAÇÃO UTF-8 PARA ACENTUAÇÃO
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 3. CARREGAMENTO DA INTERFACE
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "INSTALADOR DE CATÁLOGOS EXPRESSOS IDEIA2001"
$form.Size = New-Object System.Drawing.Size(600,600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Fontes e Cores
$fontTitle = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Variáveis Globais
$script:installDir = ""
$script:logLines = @()

# ==========================================
# PAINEL 1: ORIENTAÇÕES E SELEÇÃO DE PASTA
# ==========================================
$pnl1 = New-Object System.Windows.Forms.Panel
$pnl1.Dock = "Fill"
$form.Controls.Add($pnl1)

$txtInstructions = New-Object System.Windows.Forms.RichTextBox
$txtInstructions.Location = New-Object System.Drawing.Point(20, 20)
$txtInstructions.Size = New-Object System.Drawing.Size(540, 200)
$txtInstructions.ReadOnly = $true
$txtInstructions.BackColor = [System.Drawing.Color]::White
$txtInstructions.Font = $fontNormal
$txtInstructions.Text = "Orientações:`n`n" +
"• Acesse o site da Ideia2001 e baixe os catálogos desejados;`n" +
"• Copie os arquivos de cadastro (CodPers_AposConfigForm.txt e CodPers_Inicial.txt) e cole na mesma pasta onde salvou os instaladores;`n`n" +
"Caso você não tenha os arquivos de cadastro:`n" +
"  1. Instale manualmente apenas um catálogo (Ex: 3-RHO).`n" +
"  2. Acesse a pasta C:\ProgramData\Catalogo3-RHO\Configuracoes.`n" +
"  3. Copie os arquivos txt e cole na pasta dos instaladores que você vai selecionar abaixo."

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Localização dos instaladores (.exe / .msi) e dos Arquivos de Cadastro (.txt):"
$lblFolder.Location = New-Object System.Drawing.Point(20, 240)
$lblFolder.Size = New-Object System.Drawing.Size(540, 20)
$lblFolder.Font = $fontTitle

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(20, 265)
$txtPath.Size = New-Object System.Drawing.Size(430, 25)
$txtPath.Font = $fontNormal

$btnProcurar = New-Object System.Windows.Forms.Button
$btnProcurar.Text = "Procurar"
$btnProcurar.Location = New-Object System.Drawing.Point(460, 264)
$btnProcurar.Size = New-Object System.Drawing.Size(100, 27)
$btnProcurar.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Selecione a pasta com os instaladores e as licenças"
    if ($fbd.ShowDialog() -eq 'OK') {
        $txtPath.Text = $fbd.SelectedPath
    }
})

$btnAvancar1 = New-Object System.Windows.Forms.Button
$btnAvancar1.Text = "AVANÇAR"
$btnAvancar1.Location = New-Object System.Drawing.Point(410, 500)
$btnAvancar1.Size = New-Object System.Drawing.Size(150, 40)
$btnAvancar1.BackColor = [System.Drawing.Color]::MediumSeaGreen
$btnAvancar1.ForeColor = [System.Drawing.Color]::White
$btnAvancar1.Font = $fontTitle
$btnAvancar1.Add_Click({
    $script:installDir = $txtPath.Text
    if (!(Test-Path $script:installDir)) {
        [System.Windows.Forms.MessageBox]::Show("Selecione uma pasta válida.", "Aviso", 0, 48)
        return
    }

    $hasTxt1 = Test-Path (Join-Path $script:installDir "CodPers_AposConfigForm.txt")
    $hasTxt2 = Test-Path (Join-Path $script:installDir "CodPers_Inicial.txt")
    $installers = Get-ChildItem -Path $script:installDir | Where-Object { $_.Extension -match "\.(exe|msi)$" }
    
    if (-not ($hasTxt1 -and $hasTxt2 -and ($installers.Count -gt 0))) {
        [System.Windows.Forms.MessageBox]::Show("ERRO:`nArquivos não encontrados.`n`nOs arquivos .exe ou .msi e os dois arquivos .txt de configuração DEVEM estar na mesma pasta.", "ERRO DE VALIDAÇÃO", 0, 16)
        return
    }

    $clbItems.Items.Clear()
    foreach ($inst in $installers) {
        $clbItems.Items.Add($inst.Name) | Out-Null
    }

    $pnl1.Visible = $false
    $pnl2.Visible = $true
})

$pnl1.Controls.AddRange(@($txtInstructions, $lblFolder, $txtPath, $btnProcurar, $btnAvancar1))

# ==========================================
# PAINEL 2: SELEÇÃO DOS CATÁLOGOS
# ==========================================
$pnl2 = New-Object System.Windows.Forms.Panel
$pnl2.Dock = "Fill"
$pnl2.Visible = $false
$form.Controls.Add($pnl2)

$chkAll = New-Object System.Windows.Forms.CheckBox
$chkAll.Text = "SELECIONAR TODOS"
$chkAll.Location = New-Object System.Drawing.Point(20, 20)
$chkAll.Size = New-Object System.Drawing.Size(200, 25)
$chkAll.Font = $fontTitle

$clbItems = New-Object System.Windows.Forms.CheckedListBox
$clbItems.Location = New-Object System.Drawing.Point(20, 50)
$clbItems.Size = New-Object System.Drawing.Size(540, 430)
$clbItems.CheckOnClick = $true
$clbItems.Font = $fontNormal

$chkAll.Add_CheckedChanged({
    for ($i = 0; $i -lt $clbItems.Items.Count; $i++) {
        $clbItems.SetItemChecked($i, $chkAll.Checked)
    }
})

$btnCancelar2 = New-Object System.Windows.Forms.Button
$btnCancelar2.Text = "CANCELAR"
$btnCancelar2.Location = New-Object System.Drawing.Point(20, 500)
$btnCancelar2.Size = New-Object System.Drawing.Size(150, 40)
$btnCancelar2.BackColor = [System.Drawing.Color]::Crimson
$btnCancelar2.ForeColor = [System.Drawing.Color]::White
$btnCancelar2.Font = $fontTitle
$btnCancelar2.Add_Click({
    $pnl2.Visible = $false
    $pnl1.Visible = $true
})

$btnAvancar2 = New-Object System.Windows.Forms.Button
$btnAvancar2.Text = "AVANÇAR"
$btnAvancar2.Location = New-Object System.Drawing.Point(410, 500)
$btnAvancar2.Size = New-Object System.Drawing.Size(150, 40)
$btnAvancar2.BackColor = [System.Drawing.Color]::MediumSeaGreen
$btnAvancar2.ForeColor = [System.Drawing.Color]::White
$btnAvancar2.Font = $fontTitle
$btnAvancar2.Add_Click({
    if ($clbItems.CheckedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Selecione pelo menos um catálogo para instalar.", "Aviso", 0, 48)
        return
    }
    $pnl2.Visible = $false
    $pnl3.Visible = $true
    Start-Sleep -Milliseconds 200
    & $runInstallations
})

$pnl2.Controls.AddRange(@($chkAll, $clbItems, $btnCancelar2, $btnAvancar2))

# ==========================================
# PAINEL 3: STATUS E PROGRESSO
# ==========================================
$pnl3 = New-Object System.Windows.Forms.Panel
$pnl3.Dock = "Fill"
$pnl3.Visible = $false
$form.Controls.Add($pnl3)

$lblStatusTitle = New-Object System.Windows.Forms.Label
$lblStatusTitle.Text = "STATUS DA INSTALAÇÃO"
$lblStatusTitle.Location = New-Object System.Drawing.Point(20, 20)
$lblStatusTitle.Size = New-Object System.Drawing.Size(200, 20)
$lblStatusTitle.Font = $fontTitle

$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Location = New-Object System.Drawing.Point(20, 45)
$rtbLog.Size = New-Object System.Drawing.Size(540, 400)
$rtbLog.ReadOnly = $true
$rtbLog.BackColor = [System.Drawing.Color]::Black
$rtbLog.ForeColor = [System.Drawing.Color]::LimeGreen
$rtbLog.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)

$lblProgresso = New-Object System.Windows.Forms.Label
$lblProgresso.Text = "Preparando..."
$lblProgresso.Location = New-Object System.Drawing.Point(20, 460)
$lblProgresso.Size = New-Object System.Drawing.Size(540, 20)
$lblProgresso.Font = $fontNormal

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 480)
$progressBar.Size = New-Object System.Drawing.Size(540, 25)
$progressBar.Minimum = 0
$progressBar.Maximum = 100

$pnl3.Controls.AddRange(@($lblStatusTitle, $rtbLog, $lblProgresso, $progressBar))

function Write-UIStatus($message) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    $rtbLog.AppendText("[$timestamp] $message`r`n")
    $rtbLog.ScrollToCaret()
    $script:logLines += "[$timestamp] $message"
    [System.Windows.Forms.Application]::DoEvents()
}

# ==========================================
# LÓGICA DE INSTALAÇÃO
# ==========================================
$runInstallations = {
    $items = $clbItems.CheckedItems
    $total = $items.Count
    $current = 0
    $successCount = 0
    $errorCount = 0

    $script:logLines += "=== INÍCIO DA INSTALAÇÃO: $(Get-Date) ==="
    
    foreach ($item in $items) {
        $current++
        $perc = [math]::Round(($current / $total) * 100)
        $progressBar.Value = $perc
        $lblProgresso.Text = "[$current/$total] Processando: $item ($perc%)"
        
        Write-UIStatus "Processando: $item"

        $marca = $item -ireplace "instalar", "" -ireplace "catalogo", "" -ireplace "\.exe", "" -ireplace "\.msi", "" -ireplace "-", ""
        $isInstalled = $false
        
        if (Test-Path "C:\ProgramData") {
            $existingFolders = Get-ChildItem -Path "C:\ProgramData" -Directory -Filter "Catalogo*"
            foreach ($folder in $existingFolders) {
                $folderMarca = $folder.Name -ireplace "Catalogo", "" -ireplace "-", ""
                if ($folderMarca -ne "" -and $marca -match [regex]::Escape($folderMarca)) {
                    $isInstalled = $true
                    break
                }
            }
        }

        if ($isInstalled) {
            Write-UIStatus "-> O Catálogo já está instalado. Pulando."
            $successCount++
            continue
        }

        $fullPath = Join-Path $script:installDir $item
        Write-UIStatus "-> Instalando..."
        
        try {
            if ($item -match "\.msi$") {
                $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$fullPath`" /qn /norestart" -Wait -PassThru -ErrorAction Stop
            } else {
                $proc = Start-Process -FilePath $fullPath -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -PassThru -ErrorAction Stop
            }

            if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010 -or $proc.ExitCode -eq $null) {
                Write-UIStatus "-> Copiando arquivos de cadastro..."
                
                $newestFolder = Get-ChildItem -Path "C:\ProgramData" -Directory -Filter "Catalogo*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($newestFolder) {
                    $configDest = Join-Path $newestFolder.FullName "Configuracoes"
                    if (!(Test-Path $configDest)) { New-Item -ItemType Directory -Path $configDest | Out-Null }
                    
                    Copy-Item -Path (Join-Path $script:installDir "CodPers_*.txt") -Destination $configDest -Force
                    Write-UIStatus "-> Catálogo instalado com sucesso."
                    $successCount++
                } else {
                    Write-UIStatus "-> ERRO: Pasta de destino em C:\ProgramData não encontrada."
                    $errorCount++
                }
            } else {
                Write-UIStatus "-> ERRO na instalação. Código de saída: $($proc.ExitCode)"
                $errorCount++
            }
        } catch {
            Write-UIStatus "-> ERRO ao abrir o arquivo ou arquivo corrompido."
            $errorCount++
        }
        
        $script:logLines += "----------------------------------------"
    }

    $logFileName = "Log_Instalacao_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $logFilePath = Join-Path $script:installDir $logFileName
    $script:logLines | Out-File -FilePath $logFilePath -Encoding UTF8
    
    Write-UIStatus "Processo concluído! Log salvo em: $logFileName"
    $lblProgresso.Text = "Concluído 100%"

    if ($errorCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("CONCLUÍDO!`n`nTodos os $successCount catálogos foram instalados sem erros.`n`nConsulte o arquivo de log na pasta.", "Sucesso", 0, 64)
    } else {
        [System.Windows.Forms.MessageBox]::Show("CONCLUÍDO COM ALERTAS!`n`n$successCount catálogos instalados.`n$errorCount catálogos apresentaram erro ou não foram instalados.`n`nConsulte o arquivo de log na pasta.", "Aviso", 0, 48)
    }
    
    $form.Close()
}

$form.ShowDialog() | Out-Null