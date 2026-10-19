# Opens a .docx in Microsoft Word, updates the table of contents and fields,
# saves it, and exports a PDF next to it.
# Usage: powershell -File tools\finalize_docx.ps1 docs\File.docx
param([Parameter(Mandatory = $true)][string[]]$Paths)
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    foreach ($p in $Paths) {
        $full = (Resolve-Path $p).Path
        $doc = $word.Documents.Open($full)
        foreach ($t in $doc.TablesOfContents) { $t.Update() }
        $doc.Fields.Update() | Out-Null
        $doc.Save()
        $pdf = [System.IO.Path]::ChangeExtension($full, ".pdf")
        $doc.ExportAsFixedFormat($pdf, 17)
        $doc.Close()
        Write-Output "Finalized $full -> $pdf"
    }
}
finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
}
