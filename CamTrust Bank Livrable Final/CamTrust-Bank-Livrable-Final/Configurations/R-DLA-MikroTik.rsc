# CONFIGURATION DE RÉFÉRENCE – NON APPLIQUÉE TELLE QUELLE – voir rapport, section 2
# ============================================================
# R-DLA : configuration de référence (RouterOS 7.x)
# STATUT : NON VÉRIFIÉE. Rédigée, jamais appliquée.
# Hypothèses : ether1 = liaison siège (172.16.12.2/30)
#              ether2 = LAN agence (<adresse-agence>/<masque> à définir)
#              Admin 10.10.99.0/24 joignable via 172.16.12.1 (R-SIEGE Gi0/1)
# ============================================================

# --- 1. Identité -------------------------------------------------
/system identity set name=R-DLA

# --- 2. Interfaces et adressage ---------------------------------
/ip address
add address=172.16.12.2/30 interface=ether1 comment="Liaison siege"
add address=<adresse-agence>/<masque> interface=ether2 comment="LAN agence"

# --- 3. Route d'administration (M1-01) --------------------------
/ip route
add dst-address=10.10.99.0/24 gateway=172.16.12.1 comment="Admin via siege"

# --- 4. Groupes et comptes (M1-02) ------------------------------
/user group
add name=lecture policy=read,ssh,sensitive comment="Lecture seule"
# Compte de secours : saisir le mot de passe hors configuration
/user add name=secours group=full password=<masqué> comment="Secours local"
# /user disable admin   <- uniquement APRÈS test réussi du compte secours

# --- 5. AAA RADIUS (M1-03) --------------------------------------
# Ordre : ne pas activer use-radius avant que secours soit testé.
/radius
add address=10.10.99.20 service=login src-address=172.16.12.2 \
    authentication-port=1812 accounting-port=1813 \
    secret = <masqué> timeout=3s comment="SRV-ADMIN FreeRADIUS"
/user aaa set use-radius=yes accounting=yes default-group=lecture

# --- 6. Services d'administration (M1-01, M1-06) ----------------
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set www-ssl disabled=yes
set api disabled=yes
set api-ssl disabled=yes
set ssh address=10.10.99.0/24 port=22
set winbox address=10.10.99.0/24
/ip ssh set strong-crypto=yes forwarding-enabled=no

# Découverte et services MAC/Romon désactivés
/ip neighbor discovery-settings set discover-interface-list=none
/tool mac-server set allowed-interface-list=none
/tool mac-server mac-winbox set allowed-interface-list=none
/tool romon set enabled=no
/tool bandwidth-server set enabled=no

# --- 7. Journalisation distante (M1-04) -------------------------
/system logging action
add name=remote-syslog target=remote remote=10.10.99.20 remote-port=514 syslog-facility=local0
/system logging
add topics=system,error,warning,info action=remote-syslog
add topics=account action=remote-syslog

# --- 8. NTP (M1-05) ---------------------------------------------
/system ntp client set enabled=yes servers=10.10.99.20

# --- 9. Filtrage input (M1-06, M1-07) ---------------------------
/ip firewall filter
add chain=input connection-state=established,related action=accept comment="Trafic de retour"
add chain=input connection-state=invalid action=drop comment="Paquets invalides"
add chain=input protocol=icmp src-address=172.16.12.0/30 action=accept comment="ICMP liaison siege"
add chain=input protocol=icmp src-address=10.10.99.0/24 action=accept comment="ICMP admin"
add chain=input protocol=tcp dst-port=22,8291 src-address=10.10.99.0/24 action=accept comment="SSH/Winbox admin"
add chain=input in-interface=ether2 action=drop comment="Agence : aucun acces au routeur"
add chain=input action=drop comment="Defaut : refus"

# --- 10. Filtrage forward ---------------------------------------
/ip firewall filter
add chain=forward connection-state=established,related action=accept
add chain=forward connection-state=invalid action=drop
add chain=forward in-interface=ether2 out-interface=ether1 action=accept comment="Agence vers siege (large, a restreindre)"
add chain=forward in-interface=ether1 out-interface=ether2 action=accept comment="Retour siege vers agence"
add chain=forward action=drop comment="Defaut : refus"

# --- Vérification (à lancer dans EVE-NG, noter les sorties réelles)
# /ip route print where dst-address=10.10.99.0/24
# /ping 10.10.99.20 src-address=172.16.12.2 count=5
# /radius print
# /user aaa print
# /ip service print
# /system ntp client print
# /system logging print
# /ip firewall filter print stats
