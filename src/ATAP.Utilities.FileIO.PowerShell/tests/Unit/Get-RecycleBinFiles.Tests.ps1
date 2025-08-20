Describe 'Get-RecycleBinFiles' {
  BeforeEach {
    # Mock the Shell.Application COM object
    Mock -CommandName New-Object -MockWith {
      [PSCustomObject]@{
        Namespace = {
          param ($namespaceId)
          if ($namespaceId -eq 0xA) {
            [PSCustomObject]@{
              Items = {
                [PSCustomObject]@{
                  Count = 3
                  Item  = {
                    param ($index)
                    @(
                      [PSCustomObject]@{
                        Name             = "File1.txt"
                        Path             = "C:\\RecycleBin\\File1.txt"
                        ExtendedProperty = {
                          param ($property)
                          switch ($property) {
                            'Size' { return 1024 }
                            'Date deleted' { return (Get-Date).AddDays(-1) }
                            'Type' { return 'Text Document' }
                          }
                        }
                      },
                      [PSCustomObject]@{
                        Name             = "File2.jpg"
                        Path             = "C:\\RecycleBin\\File2.jpg"
                        ExtendedProperty = {
                          param ($property)
                          switch ($property) {
                            'Size' { return 2048 }
                            'Date deleted' { return (Get-Date).AddDays(-2) }
                            'Type' { return 'Image File' }
                          }
                        }
                      },
                      [PSCustomObject]@{
                        Name             = "File3.docx"
                        Path             = "C:\\RecycleBin\\File3.docx"
                        ExtendedProperty = {
                          param ($property)
                          switch ($property) {
                            'Size' { return 4096 }
                            'Date deleted' { return (Get-Date).AddDays(-3) }
                            'Type' { return 'Word Document' }
                          }
                        }
                      }
                    )[$index]
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  It 'Should retrieve files from the Recycle Bin' {
    $result = Get-RecycleBinFiles

    $result | Should -Not -BeNullOrEmpty
    $result.Count | Should -Be 3

    $result[0].Name | Should -Be "File1.txt"
    $result[0].Path | Should -Be "C:\RecycleBin\File1.txt"
    $result[0].Size | Should -Be 1024
    $result[0].DeletionDate | Should -BeOfType [datetime]
    $result[0].Type | Should -Be "Text Document"

    $result[1].Name | Should -Be "File2.jpg"
    $result[1].Path | Should -Be "C:\RecycleBin\File2.jpg"
    $result[1].Size | Should -Be 2048
    $result[1].Type | Should -Be "Image File"

    $result[2].Name | Should -Be "File3.docx"
    $result[2].Path | Should -Be "C:\RecycleBin\File3.docx"
    $result[2].Size | Should -Be 4096
    $result[2].Type | Should -Be "Word Document"
  }

  It 'Should return a warning if the Recycle Bin is empty' {
    Mock -CommandName New-Object -MockWith {
      [PSCustomObject]@{
        Namespace = {
          param ($namespaceId)
          if ($namespaceId -eq 0xA) {
            [PSCustomObject]@{
              Items = {
                [PSCustomObject]@{
                  Count = 0
                }
              }
            }
          }
        }
      }
    }

    $result = Get-RecycleBinFiles

    $result | Should -BeNullOrEmpty
  }
}
