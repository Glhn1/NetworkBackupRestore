# NetworkBackupRestore
PowerShell script to backup and restore network adapter settings in JSON format. 

Kodun Amacı:
  Bu PowerShell projesi, bilgisayarın ağ (network) adaptör ayarlarını yedekleyip gerektiğinde geri yüklemeyi sağlar.
Amaç, özellikle sistem değişikliği, formatlama veya IP yapılandırması gibi durumlarda kullanıcıların ağ ayarlarını manuel olarak yeniden yapılandırmak zorunda kalmadan eski ayarları kolayca geri getirebilmesini sağlamaktır.

Kullanıcı, iki moddan birini seçebilir:
-Backup: Tüm ağ adaptörlerinin IP ayarlarını masaüstüne JSON formatında yedekler.
-Restore: Daha önce alınan yedeği kullanarak sadece statik IP atanmış adaptörlerin IP yapılandırmalarını geri yükler.


Mevcut Durum:
⦁	Backup (Yedekleme) İşlemi
Bilgisayardaki tüm aktif ağ adaptörlerinin:
⦁	IP adresi,
⦁	Subnet Mask (PrefixLength),
⦁	MAC adresi,
⦁	DHCP ile mi atanmış bilgisi, JSON formatında bir dosyaya kaydedilmektedir.
⦁	Dosya ismi, tarih ve saat bilgisi içerir ve masaüstüne .json uzantılı olarak kaydedilir.
⦁	Yedek alma başarılı şekilde çalışmaktadır.


⦁	Restore (Geri Yükleme) İşlemi
⦁	Kullanıcıdan masaüstündeki .json dosya adını girmesi istenir.
⦁	Dosya JSON olarak başarıyla açılır.
Her adaptör için:
⦁	Eğer adaptör DHCP kullanıyorsa, ayarlara dokunulmaz.
Eğer adaptör statik IP kullanıyorsa:
⦁	Önce adaptöre atanmış mevcut IPv4 adresleri temizlenir.
⦁	Ardından JSON dosyasındaki IP ve Subnet bilgileri tekrar atanır.
⦁	Böylece yedeklenmiş ayarlar doğru bir şekilde geri yüklenmiş olur.


ÖRNEK:  
    # Yedekleme yapmak için:
    .\NetworkBackupRestore.ps1 -Backup

    # Geri yükleme yapmak için:
    .\NetworkBackupRestore.ps1 -Restore

Notlar:
⦁	Script, yalnızca IPv4 adresleri ile çalışır.
⦁	DHCP ile atanmış adaptörlere dokunulmaz, yalnızca statik IP’li adaptörler restore edilir.
⦁	Proje, sistemdeki tüm aktif ağ adaptörleri ile çalışır.
⦁	Yedek dosyaları JSON formatındadır ve düzenlenebilir. 
