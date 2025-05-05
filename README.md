# Budget Application

En webbapplikation för att hantera personliga budgetar. Användare kan skapa, redigera och dela budgetposter, och se andras delade budgetinlägg.

## Projektbeskrivning

Detta projekt är en budgetapplikation byggd med Ruby, Sinatra, SQLite och Slim. Applikationen följer MVC-designmönstret och inkluderar följande funktioner:

- Användarregistrering och inloggning
- Skapa, redigera och ta bort budgetposter
- Välja kategorier för budget från en databas
- Dela budgetposter offentligt
- Se andra användares delade budgetposter
- Admin-panel för användarhantering

## Mappstruktur

Projektet har följande mappstruktur:

- **/**: Huvudmappen med app.rb (huvudkontroller)
- **/model/**: Innehåller model.rb med all databaslogik, validering och affärsregler
- **/views/**: Slim-mallar för all HTML-presentation
  - layout.slim: Huvudlayout för alla sidor
  - layout_navbar.slim: Navigation
  - user_login.slim & user_register.slim: Användarautentisering
  - budget.slim, new_budget.slim, edit_budget.slim: Budget CRUD
  - public_budgets.slim: Visar andra användares offentliga budgetar
  - admin_login.slim, admin_dashboard.slim: Admin-funktionalitet
- **/public/**: Statiska filer
  - /css/: CSS-stilmallar
  - /js/: JavaScript-filer
  - /img/: Bilder för applikationen
- **/db/**: Innehåller SQLite-databasen och databasprojektfiler

## Användarroller

Applikationen har två användarroller:

### Standardanvändare
- Kan registrera sig och logga in
- Kan hantera egna budgetposter (skapa, redigera, ta bort)
- Kan välja kategori för budgetposter
- Kan göra budgetposter privata eller offentliga
- Kan se andra användares offentliga budgetposter

### Admin
- Kan logga in via admin-sidan (/admin)
- Kan se en lista över alla användare
- Kan ta bort användarkonton
- Kan inte radera sitt eget admin-konto

## Installation och körning

1. Säkerställ att Ruby är installerat (minst version 2.6)
2. Klona detta repository
3. Installera beroenden: `bundle install`
4. Kör applikationen: `ruby app.rb`
5. Öppna http://localhost:4567 i en webbläsare

### Initial admin-setup

För att skapa det första admin-kontot:

1. Gå till /setup/admin
2. Använd admin-nyckeln: `NoIjKY8It2eu1xURfwGx`
3. Ange önskat användarnamn och lösenord

## Krav för användning

- Ruby (minst 2.6)
- Sinatra
- SQLite3
- BCrypt (för lösenordshashning)
- Slim (för HTML-mallar)

## YARD-dokumentation

Koden är dokumenterad enligt YARD-standarden. För att generera dokumentation:

1. Installera YARD: `gem install yard`
2. Generera dokumentation: `yard doc`
3. Öppna dokumentationen i doc/index.html

Dokumentationen innehåller:
- Metodbeskrivningar
- Parametertyper och beskrivningar
- Returvärdesbeskrivningar
- Exempel på användning

## RESTful Routes

Applikationen följer RESTful-principer för resurser:

- **GET /budgets**: Lista alla budgetposter
- **GET /budgets/new**: Formulär för att skapa ny budgetpost
- **POST /budgets**: Skapa ny budgetpost
- **GET /budgets/:id/edit**: Formulär för att redigera budgetpost
- **PATCH /budgets/:id**: Uppdatera budgetpost
- **DELETE /budgets/:id**: Ta bort budgetpost

## Säkerhetsfunktioner

- BCrypt för säker lösenordslagring
- Cooldown för inloggningsförsök (5 försök, 5 minuter cooldown)
- Validering av användarnamn och lösenord
- Skydd mot CSRF-attacker
- Behörighetskontroll för känsliga routes

## Databasschema

Databasen innehåller följande tabeller:

- **User**: Användardata (id, Username, Password, is_admin)
- **Budget**: Budgetposter (id, category_id, user_id, Summa, Datum)
- **Category**: Budgetkategorier (id, name)
- **Permissions**: Behörigheter för budgetposter (id, budget_id, user_id, permission_type)

## Författare

Ellioth Nyman

## Projektstruktur

- `app.rb`: Huvudkontroller för Sinatra-applikationen. Hanterar routes och sessions.
- `model/`: Innehåller affärslogik och databasoperationer (t.ex. `model.rb`).
- `views/`: Slim-mallar för alla sidor och formulär.
- `public/`: Statisk front-end (CSS, JS, bilder).
- `db/`: Databasfiler och schema.
- `doc/`: Dokumentation, t.ex. ER-diagram och genererade HTML-dokument.

## Databas & ER-diagram

- Se `doc/er-diagram.png` för aktuellt ER-diagram (lägg till denna fil efter att du skapat diagrammet).
- Ny tabell: `Category` (kategori för budgetposter, används som foreign key i `Budget`).

## Nya funktioner och ändringar

- RESTful routes för budgetposter.
- Kategorier hämtas dynamiskt från databasen.
- Cooldown-funktionalitet vid inloggning.
- Förbättrad validering av formulär.
- Generellt before-block för inloggningskontroll.

## ER-diagram

Lägg till en bild på ditt ER-diagram här, t.ex. `doc/er-diagram.png`.

**Mall för ER-diagram:**
- Rektanglar för tabeller: User, Budget, Category, Permissions
- Pilar för relationer (t.ex. Budget har category_id som FK till Category)
- Markera primärnycklar (PK) och främmande nycklar (FK)

Exempel:

```
[User] 1---n [Budget] n---1 [Category]
   |                |
   |                n
   |                |
   n                [Permissions]
```

## Dokumentation av komplettering

### Mappar och filer
- `app.rb`: Huvudkontroller, hanterar routes, sessions, och logik.
- `model/model.rb`: Affärslogik och databasoperationer.
- `views/`: Slim-mallar för alla sidor och formulär.
- `public/`: Statisk front-end (CSS, JS, bilder).
- `db/`: Databasfiler och schema.
- `doc/`: Dokumentation, t.ex. ER-diagram och genererade HTML-dokument.

### Viktiga förändringar
- RESTful routes för budgetposter.
- Kategorier hämtas dynamiskt från databasen.
- Cooldown-funktionalitet vid inloggning.
- Förbättrad validering av formulär.
- before-block för inloggningskontroll.

### Exempel på problem och lösningar
- **Problem:** Hårdkodade kategorier i formulär.
  - **Lösning:** Skapade Category-tabell och hämtar kategorier dynamiskt.
- **Problem:** Bristande validering av formulär.
  - **Lösning:** Lade till backend-validering för kategori, belopp och datum.
- **Problem:** Risk för brute force på login.
  - **Lösning:** Införde cooldown efter 5 misslyckade försök.

### Felsökning
- Om en route inte fungerade efter RESTful-ändring, kontrollerade jag att alla länkar och formulär pekade på rätt path/metod.
- Vid problem med kategorier, testade jag att lägga till/ändra poster och kontrollerade att rätt kategori-id sparades och visades.

---

**Tips:** Lägg till skärmdumpar på ER-diagram och ev. felmeddelanden/problem du löst!
 
