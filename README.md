# ETL proces datasetu NorthWind
<p>
Tento repozitár obsahuje implementáciu ETL procesu v Snowflake pre analýzu dát z <b>NorthWind</b> datasetu. Projekt sa zameriava na preskúmanie správania používateľov a ich preferencií pri výbere produktov na základe hodnotení produktov a demografických údajov zákazníkov. Výsledný dátový model umožňuje multidimenzionálnu analýzu a vizualizáciu kľúčových metrik.
</p>
<hr>
<h2>1. Úvod a popis zdrojových dát</h2>
<p>
Cieľom semestrálneho projektu je analyzovať dáta týkajúce sa produktov, zákazníkov a ich hodnotení. Táto analýza umožňuje identifikovať trendy v preferenciách zákazníkov, najpopulárnejšie produkty a správanie zákazníkov.
</p>
<p>Zdrojové dáta pochádzajú z Kaggle datasetu dostupného <a href="https://www.kaggle.com/datasets/cleveranjosqlik/csv-northwind-database">tu</a>. Dataset obsahuje sedem hlavných tabuliek:</p>
<ul>
  <li><code>categories</code></li>
  <li><code>products</code></li>
  <li><code>suppliers</code></li>
  <li><code>shippers</code></li>
  <li><code>orders</code></li>
  <li><code>customers</code></li>
  <li><code>employees</code></li>
</ul>
<p>Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.</p>
<h3>1.1 Dátová architektúra</h3>
<h3>ERD diagram</h3>
<p>Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na <b>entitno-relačnom diagrame (ERD):</b></p>
<p align="center">
  <img src="ERD_schema.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma AmazonBooks</em>
</p>

---
## **2 Dimenzionálny model**

Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`fact_orderdetails`**, ktorá je prepojená s nasledujúcimi dimenziami:
- **`dim_products`**: Obsahuje podrobné informácie o produktoch (name, category, supplier_name,country,city).
- **`dim_shippers`**: Obsahuje údaje o zasielateľoch(shipper name).
- **`dim_employees`**: Obsahuje údaje o zamestnancoch (first name, last name, birth year).
- **`dim_customers`**: Obsahuje údaje o zákazníkoch (name, city, country).
- **`dim_date`**: Zahrňuje informácie o dátumoch objednavok (deň, mesiac, rok, štvrťrok).

Štruktúra hviezdicového modelu je znázornená na diagrame, ktorý ilustruje prepojenia medzi faktovou tabuľkou a jednotlivými dimenziami. Tento prístup uľahčuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="STAR_schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre NorthWind</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces zahŕňal tri kľúčové fázy: `extrakciu` (Extract), `transformáciu` (Transform) a `načítanie` (Load). Tento postup bol realizovaný v Snowflake s cieľom spracovať zdrojové dáta zo staging vrstvy a pripraviť ich do viacdimenzionálneho modelu, optimalizovaného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta z `.csv` súboru boli nahrané do Snowflake pomocou interného stage úložiska `my_stage`, ktoré slúži na dočasný import alebo export dát. Stage bol vytvorený príkazom:

```sql
CREATE OR REPLACE STAGE my_stage;
```

Do stage boli nahrané súbory obsahujúce údaje o produktoch, zákazníkoch, objednávkach, zamestnancoch a dodávateľoch. Tieto dáta boli importované do staging tabuliek pomocou príkazu `COPY INTO`. Pre každú tabuľku bol použitý podobný príkaz:

```sql
COPY INTO categories_staging
FROM @my_stage/categories.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

Po úspešnom importe dát je potrebné overiť správnosť pridania údajov do tabuľky. Na tento účel môžeme vykonať jednoduchý SQL dotaz, ktorý zobrazí prvých niekoľko riadkov z tabuľky:

```sql
SELECT * FROM categories_staging
```
Tento dotaz nám umožní skontrolovať, či boli údaje správne naimportované a či zodpovedajú očakávanému formátu.

---
### **3.2 Transform (Transformácia dát)**

Dáta zo staging tabuliek boli vyčistené, transformované a obohatené s cieľom pripraviť dimenzie a faktovú tabuľku pre efektívnu analýzu.

Dimenzia `dim_products` je navrhnutá na uchovávanie informácií o produktoch, vrátane ich názvov, kategórií, dodávateľov a geografických údajov. Transformácia zahŕňa spájanie údajov o produktoch s informáciami o kategóriách a dodávateľoch. Táto dimenzia je typu SCD Type 1, čo znamená, že keď dôjde k zmene informácií o produkte (napr. zmene kategórie alebo dodávateľa), staré údaje sú jednoducho aktualizované novými. Neuchováva sa história zmien.

Táto dimenzia poskytuje kontext pre analýzu objednávok a hodnotení produktov na základe rôznych atribútov, ako je kategória produktu, názov dodávateľa a jeho geografická poloha.
```sql
CREATE TABLE dim_products AS
SELECT DISTINCT
    p.ProductID,
    p.ProductName,
    c.CategoryName AS ProductCategory,
    s.SupplierName,
    s.Country,
    s.City
FROM products_staging p
JOIN categories_staging c ON p.CategoryID = c.CategoryID
JOIN suppliers_staging s ON p.SupplierID = s.SupplierID;

```

---
### **3.3 Load (Načítanie dát)**

Po úspešnom vytvorení dimenzií a faktovej tabuľky boli dáta nahraté do finálnej štruktúry. Na záver boli staging tabuľky odstránené, aby sa optimalizovalo využitie úložiska:
```sql
DROP TABLE IF EXISTS books_staging;
DROP TABLE IF EXISTS education_levels_staging;
DROP TABLE IF EXISTS occupations_staging;
DROP TABLE IF EXISTS ratings_staging;
DROP TABLE IF EXISTS users_staging;
```
ETL proces v Snowflake umožnil spracovanie pôvodných dát z formátu `.csv` do viacdimenzionálneho modelu typu hviezda. Tento proces zahŕňal čistenie, obohacovanie a reorganizáciu údajov z rôznych tabuliek ako Orders, Customers, Employees, Products, a Shippers. Výsledný model umožňuje detailnú analýzu obchodných transakcií, predaja produktov, preferencií zákazníkov a správania zamestnancov, pričom poskytuje základ pre vizualizácie a reporty, ktoré sa dajú využiť pre optimalizáciu obchodných procesov, zlepšenie zákazníckej skúsenosti a analýzu výkonnosti.

---
## **4 Vizualizácia dát**

