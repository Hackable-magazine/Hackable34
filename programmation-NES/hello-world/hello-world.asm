;; Hello world pour NES
;;;;;;;;;;;;;;;;;;;;;;;

;; Quelques définitions
PPUCTRL   EQU $2000
PPUMASK   EQU $2001
PPUSTATUS EQU $2002
PPUADDR   EQU $2006
PPUDATA   EQU $2007

  ENUM $0000  ; Les variables "rapides"
vbl_cnt  DS.B 1  ; Compteur de VBL (50 Hz)
vbl_flag DS.B 1  ; Mis à 1 par la VBL
  ENDE

;; L'entête pour les émulateurs
   DC.B "NES", $1a ; l'entête doit toujours commencer ainsi
   DC.B 1          ; Le nombre de boitiers de 16 Ko de ROM CPU (1 ou 2)
   DC.B 1          ; Le nombre de boitiers de 8 Ko de ROM PPU
   DC.B 0          ; Le type de cartouche, ici on veut le plus simple
   DS.B 9, $00     ; puis juste 9 zéros pour faire 16 en tout

;; Début du programme
   BASE $C000
RESET:
  LDA #0      ; Remise à zéro
  STA vbl_cnt ;   du compteur de VBL
  STA PPUCTRL ;   du Controle du PPU
  STA PPUMASK ;   du Mask du PPU
  STA $4010   ; et de
  LDA #$40    ;   tout
  STA $4017   ;     l'APU

  LDX #$ff    ; Initialise la pile à 255
  TXS

;; On attend un peu que le PPU se réveille
  BIT PPUSTATUS
- BIT PPUSTATUS ; On boucle tant que le
  BPL -         ; PPU n'est pas prêt

;; Remise à zéro de toute la RAM
  LDA #0       ; Place 0 dans A
  TAX          ;   et dans X
- STA $0000,X  ; Efface l'adresse   0 + X
  STA $0100,X  ; Efface l'adresse 256 + X
  STA $0200,X  ; Efface l'adresse 512 + X
  STA $0300,X  ;   etc.
  STA $0400,X
  STA $0500,X
  STA $0600,X
  STA $0700,X
  INX          ; Incrémente X
  BNE -        ; et boucle tant que X ne revient pas à 0

;; On attend encore un peu le PPU, au cas où
  lda PPUSTATUS

;; Chargement de la palette de couleurs
  LDA #$3F    ; On positionne le registre
  STA PPUADDR ;   d'adresse du PPU
  LDA #$00    ;   à la valeur $3F00
  STA PPUADDR

  LDX #0         ; Initialise X à 0
- LDA palette,X  ; On charge la Xième couleur
  STA PPUDATA    ;   pour l'envoyer au PPU
  INX            ; On passe à la couleur suivante
  CPX #32        ; Et ce, 32 fois
  BNE -          ; Boucle au - précédent

;; Effaçage des attributs
  LDA PPUSTATUS  ; On se resynchronise
  LDA #$23       ; Le registre d'adresse PPU
  STA PPUADDR    ;   est chargé avec la valeur
  LDA #$C0       ;   $23C0
  STA PPUADDR    ;   (attributs de la nametable 0)

  LDA #0         ; Initialise A
  TAX            ;   et X à zéro
- STA PPUDATA    ;   0 est envoyé au PPU
  INX            ; Et on boucle
  CPX #64        ;   64 fois
  BNE -

  ;; put background
  LDA PPUSTATUS  ; Resynchronisation
  LDA #$20       ;   On copie maintenant
  STA PPUADDR    ;     vers l'adresse $2000
  LDA #$00
  STA PPUADDR

  LDX #0
- LDA nametable,X   ; On charge les 256 premiers octets
  STA PPUDATA       ;   depuis notre nametable
  INX
  BNE -

  TXA               ; Puis 256 zéros
- STA PPUDATA
  INX
  BNE -

- STA PPUDATA       ; Et encore 256 zéros
  INX
  BNE -

- STA PPUDATA       ; Et finalement 192 zéros
  INX
  CPX #192          ; 256 + 256 + 256 + 192 = 960
  BNE -

  BIT PPUSTATUS ; Resynchronisation
- BIT PPUSTATUS ; on attend une dernière fois
  BPL -

;; Avant de rebrancher le PPU
  LDA #%10010000 ; Réactivation, avec les tuiles de fond en $1000
  STA PPUCTRL
  LDA #%00011110 ; On veut montrer le fond au moins
  STA PPUMASK

  JMP mainloop

;; La routine VBL
VBL:
  PHA          ; On sauvegarde A sur la pile
  LDA #1       ; On indique à la partie principale
  STA vbl_flag ;   que la VBL a eu lieu
  INC vbl_cnt  ; Et on incrémente le compteur de VBL
  PLA          ; Récupération de A
  RTI          ; Fin de routine d'interruption

;; La boucle principale du programme
mainloop:
- LDA vbl_flag ; On a attend que la VBL ait lieu
  BEQ -
  LDA #0       ; et on réinitialise le drapeau
  STA vbl_flag

  ; Et comme on n'a rien d'autre à faire...
  ; on ne fait que boucler
  JMP mainloop

;; Les données
palette: ; bleu sur rose pale
  DC.B $36,$11,$11,$11, $36,$11,$11,$11, $36,$11,$11,$11, $36,$11,$11,$11
  DC.B $36,$11,$11,$11, $36,$11,$11,$11, $36,$11,$11,$11, $36,$11,$11,$11

nametable:
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,   "HELLO, WORLD!",          0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
  DC.B 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0

;; Les vecteur du 6502
  ORG $FFFA
  DC.W VBL    ; Appelé à chaque début d'image
  DC.W RESET  ; Appelé au lancement
  DC.W $00    ; Inutilisé

  INCBIN "gfx.chr"  ; la ROM du PPU
