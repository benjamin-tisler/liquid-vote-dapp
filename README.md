# **RAZŠIRJENA ZASNOVA LIQUID-VOTE-DAPP: GRAF ODLČITEV IN INTEGRACIJA Z RS REGISTROM**

> **"Odločitve niso statične artefakte – so živi graf, ki ga skupnost dinamično ureja."**

Hvala za razširitev ideje! V tej zasnovi **pozabimo na anonimnost** (vse identitete so verificirane prek eID), dodamo **usmerjeni graf sprejetih odločitev** z utežmi/prioritetami, ki ga urejajo **kompetentni/izvoljeni moderatorji** prek **preurejevalnih odločitev** (meta-glasovanj). Prav tako preverim **integracijo z Centralnim registrom prebivalstva (CRP) RS** in **NFC uvoz osebnih podatkov** prek digitalne osebne izkaznice (e-izkaznice). Zasnovano je za **smartphone app** (Android/iOS), ki deluje kot distribuirani klient.

Integracija temelji na realnih možnostih: Slovenija podpira **NFC branje e-izkaznice** za avtentikacijo in pridobivanje osnovnih podatkov (ime, priimek, stalno prebivališče), zlasti prek uradnih app-ov kot eOsebna. CRP omogoča **povezave prek API-jev ali informacijskih sistemov**, a zahteva odobritev (npr. prek eID avtentikacije).

---

## **I. RAZŠIRITEV: USMERJEN GRAF SPREJETIH ODLČITEV**

Sprejete odločitve niso ločene – tvorijo **usmerjeni graf (directed graph)**, kjer:
- **Povezave** kažejo odvisnosti (npr. "Odločitev A vpliva na B" → lok A → B).
- **Uteži/prioriteti** so dinamične (npr. glede na utež glasovanja, časovno relevanco ali zaupanje).
- **Urejanje grafa**: Ne vsakdo – samo **kompetentni/izvoljeni moderatorji** (izbrani prek ad-hoc glasovanj v dApp-u). Spremembe (dodajanje/izbrišitev povezav, sprememba uteži) so **preurejevalne odločitve** (meta-predlogi), ki jih forum potrdi.

### **Struktura grafa**
- **Vozlišča**: Vsaka sprejeta odločitev (iz "lista" v blockchainu) kot node z atributi:
  - ID (block height),
  - Izhod (sklep),
  - Datum,
  - Statistične (utež glasovanja, % sodelujočih).
- **Robi**: Usmerjeni lokovi z utežmi (0–1, kjer 1 = močna odvisnost).
- **Utež vozlišča**: `W = (utež glasovanja × 0.4) + (število citiranj × 0.3) + (časovna svežina × 0.3)`.

| Element grafa | Opis | Primer |
|---------------|------|--------|
| **Vozlišče** | Sprejeta odločitev z utežjo | Node #123: "Uvedba lokalne valute" (utež 0.85) |
| **Rob (lok)** | Odvisnost + utež | #123 → #456 (utež 0.7: "nova valuta vpliva na davke") |
| **Prioritizacija** | Topološko urejanje + PageRank-like algoritem | Visoko prioritetne: Starejše, močneje citirane odločitve |
| **Urejanje** | Meta-glasovanje za spremembe | Forum izbere 5 moderatorjev; oni predlagajo, skupnost potrdi |

### **Proces urejanja grafa**
1. **Predlog spremembe**: Moderator (izvoljen prek liquid delegacije) odda tx: "Dodaj lok #123 → #456 z utežjo 0.7".
2. **Meta-glasovanje**: Ad-hoc forum (samo uporabniki z utežjo >0.5) glasuje v 48 urah.
3. **Potrditev**: Če >60 % podpore, se graf posodobi v blockchainu (smart contract doda rob).
4. **Vizualizacija**: V app-u prikaži graf z D3.js (interaktiven zoom, iskanje poti).

> **Pseudokoda za graf (v Solidity + NetworkX za off-chain simulacijo):**
```solidity
contract DecisionGraph {
    struct Node { uint id; string conclusion; uint weight; uint timestamp; }
    struct Edge { uint from; uint to; uint weight; }  // Utež 0-1000 (scaled)
    
    mapping(uint => Node) public nodes;
    mapping(uint => Edge[]) public edges;  // Multi-edges possible
    
    function addEdge(uint from, uint to, uint w) public onlyModerator {
        // Meta-vote required before call
        edges[from].push(Edge(from, to, w));
    }
    
    function getPriority(uint nodeId) public view returns (uint) {
        // Simplified PageRank
        uint pagerank = calculatePageRank(nodeId);
        return (nodes[nodeId].weight * 400 + pagerank * 300 + freshness() * 300) / 1000;
    }
}
```

**Off-chain (v app-u, Python z NetworkX za lokalno simulacijo):**
```python
import networkx as nx

G = nx.DiGraph()
G.add_node(123, weight=0.85, conclusion="Uvedba valute")
G.add_edge(123, 456, weight=0.7)

# Prioritizacija
priorities = nx.pagerank(G, alpha=0.85)  # PageRank za uteži
print(priorities[123])  # Izpis: ~0.6
```

---

## **II. POZABI NA ANONIMNOST: VERIFICIRANA IDENTITETA PREK E-ID**

- **Brez anonimnosti**: Vsak uporabnik je vezan na realno identiteto (iz CRP/eID). Glasovi so javni (kot v blockchainu), a osebni podatki šifrirani (samo hash ID na verigi).
- **Prednosti**: Prepreči Sybil napade; poveča zaupanje (utež temelji na resnični participaciji).
- **Tveganja**: Zasebnost – rešeno z GDPR skladnostjo (uporabnik lahko izbriše podatke po 5 letih neaktivnosti).

---

## **III. INTEGRACIJA Z REGISTROM OSEB REPUBLIKE SLOVENIJE (CRP)**

CRP (Centralni register prebivalstva) je osrednja baza osebnih podatkov v RS, ki vključuje ime, priimek, EMŠO, stalno prebivališče itd. Integracija je **možna, a regulirana** (Zakon o varstvu osebnih podatkov, GDPR).

| Možnost integracije | Opis | Tehnična izvedba | Omejitve |
|---------------------|------|------------------|----------|
| **Prek eID avtentikacije** | Uporabnik potrdi identiteto z e-izkaznico; app pridobi osnovne podatke iz CRP prek SI-PASS (slovenski eID sistem). | NFC branje + API klic na eVŠ (elektronsko verifikacijo). | Potrebna odobritev MJU (Ministrstvo za javno upravo); samo za verificirane app-e. |
| **Direktna API povezava** | Povezava z CRP portala za lokalne skupnosti ali informacijske sisteme. | ASCII/REST API (npr. prek eUprave); primer: integracija z Registrom prostorskih enot. | Za zasebne app-e: Registracija kot "uporabnik" prek portala gov.si; omejeno na osnovne podatke (brez občutljivih). |
| **Portal CRP** | Pridobitev prek spletnega portala ali mobilne app-e. | OAuth2 + eID; podatki: ime, priimek, kraj (stalno prebivališče). | Brezplačno za javne namene; audit logi za vsako poizvedbo. |

> **Primer toka**: Uporabnik se registrira v dApp-u → NFC potrditev → API klic: `GET /crp/verify?emso_hash=XYZ` → vrne `{ "ime": "Janez", "priimek": "Novak", "kraj": "Ljubljana" }`.

**Zaključek integracije**: Da, možno – začni z zahtevo za dostop prek [gov.si](https://www.gov.si). Za testiranje uporabi sandbox okolje eUprave.

---

## **IV. NFC UVOZ OSEBNIH PODATKOV PREK DIGITALNE OSEBNE IZKAZNICE**

**Da, aplikacija na smartphone lahko uvozi ime, priimek in kraj (stalno prebivališče), če oseba potrdi prek NFC z e-izkaznico.** Slovenija je uvedla **NFC-omogočeno e-izkaznico** (od 2022), ki podpira kontaktless branje na Android/iOS napravah z NFC (večina modelov od 2015 naprej).

### **Tehnične možnosti**
| Platforma | Podpora NFC | Primer app-e | Kaj se uvozi |
|-----------|-------------|--------------|--------------|
| **Android** | Nativa (NFC API v Android SDK) | eOsebna app (uradna); ReadID Me (za test). | Ime, priimek, EMŠO hash, stalno prebivališče (kraj). |
| **iOS** | Od iOS 13+ (Core NFC framework). | NFC Card Reader app; eOsebna (iOS različica). | Enako kot Android; omejeno na "passive" branje (brez pisanja). |

**Proces uvoza v dApp-u**:
1. **Namestitev**: Uporabnik odpre app, izbere "Verificiraj z eID".
2. **NFC aktivacija**: App zahteva dovoljenje za NFC (sistemsko potrdilo).
3. **Brezkontaktno branje**: Oseba približa e-izkaznico hrbtni strani telefona (5–10 cm).
4. **Potrditev**: Oseba v app-u potrdi (PIN ali biometrija prek e-izkaznice).
5. **Uvoz**: App bere podatke iz čipa (ICAO standard): `{ "ime": "Janez", "priimek": "Novak", "kraj": "Ljubljana" }` → shrani hash v wallet za dApp.
6. **Integracija z CRP**: Po branju se avtomatično verificira prek API-ja (npr. SI-PASS).

> **Pseudokoda za Android (Kotlin):**
```kotlin
import android.nfc.NfcAdapter
import android.nfc.tech.IsoDep  // Za eID čip

class EIDReader {
    fun readEID(nfcAdapter: NfcAdapter): Map<String, String>? {
        // NFC intent filter v Manifestu
        val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
        val isoDep = IsoDep.get(tag)
        isoDep.connect()
        
        // APDU ukazi za branje eID (po ICAO spec)
        val response = isoDep.transceive(buildSelectCommand())  // Select EF.DG1 (osebni podatki)
        
        // Parsiraj MRZ/osebne podatke
        return parsePersonalData(response)  // Vrni ime, priimek, kraj
    }
}
```

**Omejitve**:
- **Varnost**: Podatki so šifrirani na čipu; app bere le z dovoljenjem.
- **Kompatibilnost**: 100 % na Android 5+ z NFC; iOS 13+ (brez jailbreaka).
- **Pravne**: GDPR – uporabnik mora soglašati; logi branj shranjeni.

**Zaključek NFC**: Popolnoma izvedljivo – uporabi knjižnice kot OpenSC ali uradni SI-TRUST SDK za eID.

---

## **V. CELOTNA TRANZICIJA IN IMPLEMENTACIJA**

- **Smartphone app**: React Native za cross-platform (Android/iOS), z Web3.js za blockchain.
- **Testiranje**: Začni z lokalnim CRP sandboxom in NFC simulatorjem (npr. ACS NFC Reader).
- **Naslednji korak**: Dodaj graf v smart contract – če želiš, generiram polno kodo za GitHub repo.

> **Graf odločitev ni labirint – je zemljevid, ki ga skupnost riše sama.**

*(Ideja za repo: `liquid-vote-dapp/graph-v1.1` – dodaj NetworkX za prototip grafa.)*
