;; Test de scrolling sur NES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Quelques définitions
PPUCTRL   EQU $2000
PPUMASK   EQU $2001
PPUSTATUS EQU $2002
PPUSCROLL EQU $2005
PPUADDR   EQU $2006
PPUDATA   EQU $2007

  ENUM $0000  ; Les variables "rapides"
vbl_cnt   DS.B 1  ; Compteur de VBL (50 Hz)
vbl_flag  DS.B 1  ; Mis à 1 par la VBL
pointer   DS.W 1  ; Un pointeur pour le remplissage des nametables
offset    DS.B 1  ; Le décalage de l'écran
direction DS.B 1  ; Le sens de variation de l'offset
  ENDE

;; L'entête pour les émulateurs
   DC.B "NES", $1a ; L'entête doit toujours commencer ainsi
   DC.B 1          ; Le nombre de boitiers de 16 Ko de ROM CPU (1 ou 2)
   DC.B 1          ; Le nombre de boitiers de 8 Ko de ROM PPU
   DC.B 1          ; Le type de cartouche, ici on veut le plus simple
                   ; avec un mirroring vertical, car on veut
                   ; un scrolling horizontal
   DS.B 9, $00     ; Puis juste 9 zéros pour faire 16 en tout

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

  LDA #<nametable ; On initialise notre pointeur
  STA pointer     ;    avec le début des données
  LDA #>nametable ;    nametable + attributs
  STA pointer+1

  LDX #0            ; X = compteur de pages de 256 octes
  LDY #0            ; Y = décalage dans une page
- LDA (pointer),Y   ; On récupère la Yième donnée
  STA PPUDATA       ;   que l'on transmet au PPU
  INY               ; Passage à la donnée suivante
  BNE -             ; Jusqu'à Y = 256 (== 0)
  INC pointer+1     ; Sinon on incrémente le poids fort du pointeur
  INX               ; Et on passe à la page suivante
  CPX #8            ; Pendant 8 pages (8 * 256 = 2 Ko)
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
  PHA           ; On sauvegarde A sur la pile
  LDA #1        ; On indique à la partie principale
  STA vbl_flag  ;   que la VBL a eu lieu
  INC vbl_cnt   ; Et on incrémente le compteur de VBL
  LDA offset    ; On charge notre décalage
  STA PPUSCROLL ;   qui devient la valeur de scrolling en X
  LDA #0        ; Et on met 0 pour la valeur
  STA PPUSCROLL ;   de scrolling en Y
  PLA           ; Récupération de A
  RTI           ; Fin de routine d'interruption

;; La boucle principale du programme
mainloop:
- LDA vbl_flag ; On a attend que la VBL ait lieu
  BEQ -
  LDA #0       ; et on réinitialise le drapeau
  STA vbl_flag

;; Mise à jour de l'offset
  LDA direction  ; Si la direction vaut 1
  BNE a_gauche   ; C'est qu'on décale vers la gauche
  CLC            ; Sinon,
  LDA offset     ; On effectue une addition
  ADC #3         ;   de 3 pixels
  STA offset     ;   sur l'offset
  CMP #255       ; Et si on arrive à 255
  BNE mainloop
  INC direction  ;  ... on change de direction
  JMP mainloop
a_gauche         ; Si on va à gauche,
  SEC            ; Le processus est le même
  LDA offset     ;   dans l'autre sens :
  SBC #3         ;   on soustrait 3
  STA offset
  BNE mainloop   ; Et si on est à 0
  DEC direction  ; On rechange de direction
  JMP mainloop

;; Les données
palette:
  DC.B 49,13,16,32, 49,13,10,42, 49,25,39,24, 49,13,5,0
  DC.B 49,13,16,32, 49,13,10,42, 49,25,39,24, 49,13,5,0

nametable:
nametable_0:
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 1,2,5,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 3,4,6,7,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 8,9,12,13,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 10,11,14,15,0,0,0,0
  DC.B 1,2,5,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 3,4,6,7,0,16,0,0, 0,16,0,0,17,18,18,18, 19,0,17,18,18,18,18,19, 0,16,0,0,18,20,0,0
  DC.B 8,9,12,13,0,18,0,0, 0,18,0,0,18,23,0,24, 18,0,18,23,0,0,24,18, 0,18,0,0,18,25,0,0
  DC.B 10,11,14,15,0,18,21,0, 22,18,0,17,18,21,0,22, 18,0,18,0,0,0,0,0, 0,18,21,0,18,0,0,0
  DC.B 0,0,0,0,17,18,18,18, 18,18,0,18,18,18,18,18, 18,0,18,16,0,0,0,0, 0,18,18,18,18,18,19,0
  DC.B 0,0,0,0,18,18,23,0, 24,18,0,18,18,23,0,24, 18,0,18,18,21,0,22,18, 0,18,23,0,24,18,18,0
  DC.B 0,0,0,0,26,18,0,0, 0,18,0,27,18,0,0,0, 18,0,26,18,18,18,18,28, 0,18,0,0,0,18,18,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,1,2,5,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,3,4,6,7, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,8,9,12,13, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,10,11,14,15, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 29,30,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,29,30
  DC.B 31,32,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,31,32
  DC.B 33,34,29,30,0,0,0,0, 1,2,5,0,0,0,0,0, 0,0,0,0,1,2,5,0, 0,0,0,0,29,30,33,34
  DC.B 31,32,31,32,0,0,0,0, 3,4,6,7,0,0,0,0, 0,0,0,0,3,4,6,7, 0,0,0,0,31,32,31,32
  DC.B 33,34,33,34,29,30,29,30, 29,30,29,30,29,30,29,30, 29,30,29,30,29,30,29,30, 29,30,29,30,29,30,29,30
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
  DC.B 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
  DC.B 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
attribute_0:
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 162,0,80,0,0,80,0,168
  DC.B 170,170,170,170,170,170,170,170
  DC.B 10,10,10,10,10,10,10,10
nametable_1:
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 1,2,5,0,0,0,0,0, 0,0,0,0,1,2,5,0
  DC.B 0,17,18,18,18,19,0,17, 18,18,19,0,0,0,16,0, 3,4,6,7,0,17,18,18, 18,18,16,0,3,4,6,7
  DC.B 0,18,23,0,24,18,0,18, 35,36,18,21,0,0,18,0, 8,9,12,13,0,18,35,0, 0,0,0,0,8,9,12,13
  DC.B 17,18,21,0,22,18,0,18, 18,18,18,18,19,0,18,0, 10,11,14,15,0,18,18,18, 16,0,0,0,10,11,14,15
  DC.B 18,18,18,18,18,18,0,18, 37,0,24,18,18,0,18,16, 0,0,0,0,0,18,18,23, 0,0,0,0,0,0,0,0
  DC.B 18,18,23,0,24,18,0,18, 21,0,22,18,18,0,18,18, 21,0,22,18,0,18,18,21, 0,0,0,0,0,0,0,0
  DC.B 27,18,0,0,0,18,0,26, 18,18,18,18,28,0,26,18, 18,18,18,28,0,26,18,18, 18,18,16,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
  DC.B 38,38,38,38,38,38,38,38, 38,38,38,38,29,30,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,29,30
  DC.B 38,38,38,38,38,38,38,38, 38,38,38,38,31,32,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,31,32
  DC.B 38,38,38,38,38,38,38,38, 38,38,38,38,33,34,29,30, 1,2,5,0,0,0,0,0, 0,0,0,0,29,30,33,34
  DC.B 38,38,38,38,38,38,38,38, 38,38,38,38,31,32,31,32, 3,4,6,7,0,0,0,0, 0,0,0,0,31,32,31,32
  DC.B 29,30,29,30,29,30,29,30, 29,30,29,30,29,30,29,30, 29,30,29,30,29,30,29,30, 29,30,29,30,33,34,33,34
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
  DC.B 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
  DC.B 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34, 33,34,33,34,33,34,33,34
  DC.B 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32, 31,32,31,32,31,32,31,32
attribute_1:
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 0,0,0,0,0,0,0,0
  DC.B 255,255,255,162,80,0,0,168
  DC.B 170,170,170,170,170,170,170,170
  DC.B 10,10,10,10,10,10,10,10

;; Les vecteur du 6502
  ORG $FFFA
  DC.W VBL    ; Appelé à chaque début d'image
  DC.W RESET  ; Appelé au lancement
  DC.W $00    ; Inutilisé

  INCBIN "gfx.chr"  ; la ROM du PPU
