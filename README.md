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
  <img src="Erd_Schema.png" alt="ERD Schema">
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
- **`dim_time`**: Obsahuje podrobné časové údaje (hodina, AM/PM).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="Star_Schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre NorthWind</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**
Dáta zo zdrojového datasetu (formát `.csv`) boli najprv nahraté do Snowflake prostredníctvom interného stage úložiska s názvom `my_stage`. Stage v Snowflake slúži ako dočasné úložisko na import alebo export dát. Vytvorenie stage bolo zabezpečené príkazom:

#### Príklad kódu:
```sql
CREATE OR REPLACE STAGE my_stage;
```
Do stage boli následne nahraté súbory obsahujúce údaje o knihách, používateľoch, hodnoteniach, zamestnaniach a úrovniach vzdelania. Dáta boli importované do staging tabuliek pomocou príkazu `COPY INTO`. Pre každú tabuľku sa použil podobný príkaz:

```sql
COPY INTO categories_staging
FROM @my_stage/categories.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

---
### **3.2 Transform (Transformácia dát)**

V tejto fáze boli dáta zo staging tabuliek vyčistené, transformované a obohatené. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu.

Dimenzie boli navrhnuté na poskytovanie kontextu pre faktovú tabuľku. 
`Dim_employees` obsahuje údaje o zamestnancoch vrátane ich jedinečného identifikátora, mena, priezviska a roku narodenia. Transformácia zahŕňala premenovanie stĺpcov na zrozumiteľnejšie názvy (napr. `FirstName` na `First_Name`, `LastName` na `Last_Name`) a extrahovanie roku narodenia zo stĺpca dátumu narodenia. Táto dimenzia by mohla byť prispôsobená ako SCD 2, ak by bolo potrebné sledovať historické zmeny v údajoch zamestnancov, ako sú napríklad zmeny mena alebo iné osobné údaje v priebehu času. V súčasnej implementácii však uchováva len statické údaje.
```sql
CREATE TABLE dim_employees AS
SELECT DISTINCT
    e.EmployeeID,
    e.FirstName as First_Name,
    e.LastName as Last_Name,
    YEAR(e.BirthDate) as Birth_Year,
FROM employees_staging e;
```
`Dim_date` obsahuje údaje o dátumoch vrátane jedinečného identifikátora dátumu (DateID), konkrétneho dátumu, dňa, dňa v týždni, názvu dňa v týždni, mesiaca, názvu mesiaca, roku, týždňa a kvartálu.

Transformácia zahŕňala:
- Priradenie jedinečného identifikátora dátumu (DateID) pomocou funkcie `ROW_NUMBER`.
- Extrahovanie jednotlivých zložiek dátumu (deň, mesiac, rok, týždeň, kvartál) pomocou funkcie `DATE_PART`.
- Pridanie číselnej reprezentácie dňa v týždni (1 = Pondelok, 7 = Nedeľa).
- Transformáciu číselných hodnôt dňa v týždni a mesiaca na ich textové reprezentácie v slovenčine (napr. 1 = „Pondelok“, 1 = „Január“).

Táto dimenzia je vhodná na analytické účely, ako napríklad skupinové agregácie, sezónne analýzy alebo vytváranie časových hierarchií (deň, mesiac, kvartál, rok). Dátumová dimenzia sa vytvára z údajov v tabuľke `orders_staging` a umožňuje efektívne prepojenie faktov s konkrétnymi časovými obdobiam.
```sql
CREATE TABLE DIM_DATE AS
SELECT
    ROW_NUMBER() OVER (ORDER BY CAST(OrderDate AS DATE)) AS DateID, 
    CAST(OrderDate AS DATE) AS date,                    
    DATE_PART(day, OrderDate) AS day,                   
    DATE_PART(dow, OrderDate) + 1 AS dayOfWeek,        
    CASE DATE_PART(dow, OrderDate) + 1
        WHEN 1 THEN 'Pondelok'
        WHEN 2 THEN 'Utorok'
        WHEN 3 THEN 'Streda'
        WHEN 4 THEN 'Štvrtok'
        WHEN 5 THEN 'Piatok'
        WHEN 6 THEN 'Sobota'
        WHEN 7 THEN 'Nedeľa'
    END AS dayOfWeekAsString,
    DATE_PART(month, OrderDate) AS month,              
    CASE DATE_PART(month, OrderDate)
        WHEN 1 THEN 'Január'
        WHEN 2 THEN 'Február'
        WHEN 3 THEN 'Marec'
        WHEN 4 THEN 'Apríl'
        WHEN 5 THEN 'Máj'
        WHEN 6 THEN 'Jún'
        WHEN 7 THEN 'Júl'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'Október'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END AS monthAsString,
    DATE_PART(year, OrderDate) AS year,                
    DATE_PART(week, OrderDate) AS week,               
    DATE_PART(quarter, OrderDate) AS quarter           
FROM orders_staging
GROUP BY CAST(OrderDate AS DATE), 
         DATE_PART(day, OrderDate), 
         DATE_PART(dow, OrderDate), 
         DATE_PART(month, OrderDate), 
         DATE_PART(year, OrderDate), 
         DATE_PART(week, OrderDate), 
         DATE_PART(quarter, OrderDate);
```
`Fact_orderdetails` obsahuje údaje o detailoch objednávok, ktoré zahŕňajú transakčné dáta o produktoch, objednaných množstvách a ich cenách, ako aj odkazy na rôzne dimenzie ako produkt, zamestnanec, zákazník, dopravca, dátum a čas.

Transformácia zahŕňala:
- Priradenie jedinečného identifikátora detailu objednávky (`OrderDetailID`), ktorý jednoznačne identifikuje každú položku objednávky.
- Spojenie dát z rôznych dimenzií (produkty, zamestnanci, zákazníci, dopravcovia, dátumy a časy) prostredníctvom vonkajších kľúčov, čím sa umožňuje efektívne prepojenie faktov (detailov objednávky) s príslušnými dimenziami.
- Cena produktu a množstvo sú uložené ako metriky transakcie, ktoré umožňujú analýzu objednávok na rôznych úrovniach.
Táto faktová tabuľka je vhodná pre analytické účely, ako sú analýza predaja, sledovanie objednávok podľa produktov a zákazníkov, a meranie výkonu zamestnancov alebo dopravcov. Vytvára sa zo zdrojových dát v tabuľke `orderdetails_staging` a umožňuje flexibilné a detailné analýzy, ktoré zahŕňajú údaje o predaji a objednávkach v rámci rôznych dimenzií (produkt, zamestnanec, zákazník, dopravca, dátum, čas).
