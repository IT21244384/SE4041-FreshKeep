# Exports a .pptx to PDF with PowerPoint. Usage: powershell -File tools\pptx_to_pdf.ps1 deck.pptx
param([Parameter(Mandatory = $true)][string]$Path)
$full = (Resolve-Path $Path).Path
$pp = New-Object -ComObject PowerPoint.Application
try {
    $pres = $pp.Presentations.Open($full, $true, $false, $false)
    $pres.SaveAs([System.IO.Path]::ChangeExtension($full, ".pdf"), 32)
    $pres.Close()
} finally { $pp.Quit() }
