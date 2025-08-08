param (
    [switch]$Backup,     # Yedekleme (Backup) modunu çalıştırmak için kullanılan parametre
    [switch]$Restore     # Geri yükleme (Restore) modunu çalıştırmak için kullanılan parametre
)

# Function: Get network adapter information
function Get-NetworkAdapterInfo {
    # Tüm ağ adaptörlerini al
    $adapters = Get-NetAdapter

    # Adapter bilgilerini saklayacak boş bir dizi oluştur
    $adapterInfo = @()

    # Her bir adaptör için işlemi gerçekleştir
    foreach ($adapter in $adapters) {
        # IP adresi ve subnet maskelerini saklayacak diziler
        $ipAddresses = @()
        $subnetMasks = @()
        # DHCP kullanıp kullanmadığını kontrol etmek için bir değişken
        $isDHCP = $false

        try {
            # IPv4 ayarlarını al ve hata olursa göz ardı et
            $ipConfig = Get-NetIPConfiguration -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue
            # IPv4 adres bilgilerini al
            $ipAddressInfo = Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue

            # Eğer IP adresi mevcutsa, DHCP kullanılıp kullanılmadığını kontrol et
            if ($ipConfig.IPv4Address.IPAddress) {
                $isDHCP = $ipConfig.IPv4Address.PrefixOrigin -eq "Dhcp"
            }

            # IP adresleri ve subnet maskelerini dizilere ekle
            foreach ($ipInfo in $ipAddressInfo) {
                $ipAddresses += $ipInfo.IPAddress
                $subnetMasks += $ipInfo.PrefixLength
            }
        } catch {
            # Hata oluşursa ekrana uyarı yazdır
            Write-Output "Warning: Error while reading adapter '$($adapter.Name)': $_"
        }

        # Eğer IP adresi yoksa, "No IPv4 address" ve subnet maskesi "N/A" olarak belirle
        if ($ipAddresses.Count -eq 0) {
            $ipAddresses = "No IPv4 address"
            $subnetMasks = "N/A"
        }

        # Adaptör bilgilerini nesne olarak oluştur ve $adapterInfo dizisine ekle
        $adapterObject = [PSCustomObject]@{
            'AdapterName' = $adapter.Name        # Adaptör adı
            'IPAddress'   = $ipAddresses -join ", "  # IP adresini virgülle ayırarak birleştir
            'SubnetMask'  = $subnetMasks -join ", "   # Subnet maskelerini virgülle ayırarak birleştir
            'MACAddress'  = $adapter.MACAddress  # MAC adresi
            'IsDHCP'      = $isDHCP             # DHCP mi, statik mi olduğunu belirle
        }

        # Adapter bilgilerini dizine ekle
        $adapterInfo += $adapterObject
    }

    return $adapterInfo
}

# BACKUP MODE - Yedekleme işlemi
if ($Backup) {
    # Mevcut tarihi al, "yyyyMMdd-HHmm" formatında
    $dateStamp = Get-Date -Format "yyyyMMdd-HHmm"

    # Yedekleme dosyasının yolunu oluştur (Masaüstüne kaydedilecek)
    $outputFile = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath "networkBackup_$dateStamp.json"

    # Ağ adaptörü bilgilerini al
    $adapterInfo = Get-NetworkAdapterInfo

    # JSON formatında veriyi dışa aktar (UTF-8 encoding ile)
    $adapterInfo | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputFile -Encoding UTF8

    # Kullanıcıya yedekleme işleminin tamamlandığını bildir
    Write-Output "Backup completed. File saved as: $outputFile"
}

# RESTORE MODE - Geri yükleme işlemi
elseif ($Restore) {
    # Kullanıcıdan yedekleme dosyasının adını al
    $inputFileName = Read-Host "Enter the JSON file name on Desktop"

    # Masaüstü yolunu al
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    # Dosyanın tam yolunu oluştur
    $inputFile = Join-Path -Path $desktopPath -ChildPath $inputFileName

    # Dosya var mı kontrol et
    if (-not (Test-Path $inputFile)) {
        # Dosya bulunmazsa kullanıcıya uyarı ver
        Write-Output "File '$inputFile' not found."
        return
    }

    try {
        # JSON dosyasını oku ve veriyi JSON formatında içeri al
        $jsonContent = Get-Content -Path $inputFile -Raw | ConvertFrom-Json

        # JSON içeriğini işleyerek her adaptörü kontrol et
        foreach ($adapterInfo in $jsonContent) {
            # Adaptör adını ve DHCP durumunu al
            $adapterName = $adapterInfo.AdapterName
            $isDHCP = $adapterInfo.IsDHCP

            Write-Output "`nProcessing adapter: $adapterName (DHCP: $isDHCP)"

            if ($isDHCP -eq $true) {
                # Eğer DHCP aktifse, adaptörü değiştirmeden IP'yi göster
                $currentIP = (Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
                Write-Output "DHCP aktif, mevcut IP: $currentIP"
                continue
            }

            # Statik IP ve subnet maskelerini al
            $ipAddresses = $adapterInfo.IPAddress -split ", "
            $subnetMasks = $adapterInfo.SubnetMask -split ", "

            # Her bir IP adresini ve subnet maskesini kontrol et
            for ($i = 0; $i -lt $ipAddresses.Count; $i++) {
                $ipAddress = $ipAddresses[$i]
                $subnetMask = $subnetMasks[$i]

                if ($ipAddress -ne "No IPv4 address") {
                    try {
                        # IP zaten mevcut mu kontrol et
                        $existingIP = Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -IPAddress $ipAddress -ErrorAction SilentlyContinue
                        if ($existingIP) {
                            Write-Output "IP $ipAddress zaten atanmış, atlanıyor..."
                            continue
                        }

                        # Mevcut IP'leri temizle
                        Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

                        # Yeni IP'yi ata
                        New-NetIPAddress -InterfaceAlias $adapterName -IPAddress $ipAddress -PrefixLength $subnetMask -ErrorAction Stop
                        Write-Output "IP $ipAddress/$subnetMask uygulandı."
                    } catch {
                        Write-Output "HATA: $ipAddress atanamadı ($adapterName): $_"
                    }
                }
            }
        }

        Write-Output "`nRestore completed from '$inputFile'"
    } catch {
        Write-Output "Restore işlemi başarısız: $_"
    }
}
