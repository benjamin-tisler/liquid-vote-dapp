# **ZASNOVA DISTRIBUIRANE APLIKACIJE ZA MREŽNO ODLOČANJE: LIQUID VOTE DAPP**

> **"Demokracija ni statična – je tekoča. Blockchain jo naredi nespremenljivo."**

Ta zasnova temelji na konceptu **liquid democracy** (tekoče demokracije), ki združuje direktno glasovanje z delegacijo glasov, implementirano na blockchainu. 
Aplikacija je distribuirana (DApp), podobna Bitcoin klientu: P2P mreža, kjer vsako vozlišče (node) validira transakcije (glasove) in gradi verigo blokov (odločitev). 
Vsak posameznik ima **en unikaten glas**, vendar z **dinamično težo** na podlagi zaupanja in delegacij. Začetni parametri so enaki (teža = 1), dokler skupnost posamezniku ne dodeli večje teže prek delegacij ali zaupanja.

Inspiracija iz obstoječih sistemov: Liquid democracy v DPoS blockchainih, delegated voting v DAOs in blockchain-based electronic voting z delegacijo. Uporabljam proof-of-stake (PoS) za konsenz, podobno Tezosu, z liquid delegation za uteži.

## **I. ARHITEKTURA SISTEMA (PODOBNO BTC KLIENTU)**

Aplikacija deluje kot **decentralizirana P2P mreža**:
- **Vozlišča (Nodes)**: Vsak uporabnik zažene lokalnega klienta (kot BTC wallet), ki se poveže v mrežo.
- **Blockchain**: Veriga blokov hrani vse transakcije (glasove, delegacije) in odločitve (bloke z izidi).
- **Smart Contracts**: Za avtomatizacijo (npr. Solidity na Ethereum-compatible verigi, ali custom PoS chain kot v DPoS sistemih).
- **Sybil Resistance**: En glas na osebo – uporabi proof-of-personhood (npr. biometrični hash ali zero-knowledge proof za unikaten ID, podobno Worldcoin).

| Komponenta | Opis | Tehnologija |
|------------|------|-------------|
| **Klient** | Lokalna app za glasovanje, delegacijo in validacijo. | Electron/React za frontend, Web3.js za backend. |
| **Mreža** | P2P za širjenje transakcij. | Libp2p ali custom gossip protocol (kot BTC). |
| **Konsenz** | PoS z liquid delegation – delegirani glasovi povečajo staking težo validatorjev. | Cosmos SDK ali Substrate (Polkadot). |
| **Shranjevanje** | IPFS za off-chain podatke (npr. predlogi), blockchain za ključne tx. | Ethereum L2 (npr. Optimism) za skalabilnost. |

## **II. IDENTITETA IN ZAČETNI PARAMETRI**

- **Registracija**: Vsak uporabnik generira unikaten ključ (ECDSA, kot v BTC) in dokaže "človeškost" (npr. prek oracle za biometrijo ali social proof).
- **Začetni parametri**: Teža glasa = 1, brez delegacij. Vsak ima "staking pool" za svoj glas (podobno PoS).
- **Sprememba teže**: 
  - **Zaupanje**: Drugi glasujejo za "zaupanja vrednega" – vsak +1 zaupanja poveča težo za 0.1 (do max 10).
  - **Delegacija**: Uporabnik A delegira glas B-ju – B glasuje z težo A + B. Delegacija je revokabilna kadarkoli.
    - **Specifična**: Samo za eno zadevo (npr. "delegiram za predlog #123").
    - **Splošna**: Do preklica (npr. "delegiram B-ju za vse okoljske teme").

> **Primer**: Uporabnik A (teža 1) delegira B-ju (teža 2) → B glasuje z težo 3.

To je podobno delegated voting v DAOs, kjer delegacija vpliva na voting power.

## **III. PROCES ODLOČANJA (KOT ZBIRANJE TRANSAKCIJ V BTC)**

Proces je analogen Bitcoinu: Glasovi so transakcije (tx), zbirajo se v mempoolu, potrdijo v bloku.

1. **Predlog (Proposal Tx)**: Kdorkoli odda predlog (npr. "Ali naj uvedemo novo pravilo?"). Tx vsebuje: opis, opcije (da/ne/več), rok glasovanja.
   
2. **Delegacija (Delegation Tx)**: Uporabnik odda tx za delegacijo (specifično/splošno). Tx je signiran in broadcastan.

3. **Glasovanje (Vote Tx)**: Vsak odda tx z glasom (da/ne/abstain). Teža se izračuna dinamično (vključno delegacije).
   - Samo en glas na osebo – ponovni glas prekliče prejšnjega.
   - Tx fee: Minimalen, za preprečevanje spam (kot gas v ETH).

4. **Zbiranje Tx**: Vozlišča zbirajo tx v mempoolu do roka.

5. **Potrditev (Mining/Validation)**: Validatorji (izbrani prek PoS z utežmi) potrdijo blok. Blok je "list" z:
   - **Tipiziranim izidom**: npr. {"izid": "DA", "procent": 62.3%}.
   - **Sklepom**: Avtomatičen povzetek (npr. "Sprejeto: Novo pravilo velja.").
   - **Datumom**: Timestamp + block height.
   - **Statistiko**: Število sodelujočih, uteži, delegacije, min/max utež.

> **Konsenz mehanizem**: Liquid PoS – validatorji stakingajo z delegiranimi utežmi. Če delegiraš, tvoja utež pomaga validatorju validirati bloke.

## **IV. MATRIKA UTEŽI GLASOV (DINAMIČNA)**

Podobno prejšnji matriki, a prilagojeno blockchainu.

| Dimenzija | Formula | Spreminjanje |
|-----------|---------|--------------|
| **Osnovna teža** | 1 (začetna) | Nespremenljiva. |
| **Zaupanje (Z)** | Število zaupanja glasov / 10 | +1 za vsak "zaupam ti" tx (max 10). |
| **Delegacija (D)** | Vsota delegiranih uteži | Dinamično: Delegacija tx doda, revokacija odšteje. |
| **Aktivnost (A)** | 1 - (dnevi neaktivnosti / 365) | Pada, če ne glasuješ. |
| **Končna utež (U)** | U = 1 + Z + D + A | Izračunana ob potrditvi bloka. |

> **Primer v kodeksu (Solidity psevdo-koda):**
```solidity
contract LiquidVote {
    mapping(address => uint) public weight;  // Osnovna + zaupanje
    mapping(address => mapping(uint => address)) public delegations;  // proposalId => delegate
    event VoteCast(address voter, uint proposalId, bool vote, uint effectiveWeight);

    function castVote(uint proposalId, bool vote) public {
        uint effWeight = calculateWeight(msg.sender, proposalId);
        // Oddaj tx z utežjo
        emit VoteCast(msg.sender, proposalId, vote, effWeight);
    }

    function calculateWeight(address user, uint proposalId) internal view returns (uint) {
        uint base = 1 + trust[user];  // Zaupanje
        uint del = getDelegated(user, proposalId);  // Delegacije
        uint act = 1 - (block.timestamp - lastActive[user]) / (365 days);
        return base + del + act;
    }
}
```

## **V. VARNOST IN SKALABILNOST**

- **Sybil Attack**: Proof-of-personhood + staking kazni za zlorabo.
- **51% Attack**: Liquid PoS z delegacijo razprši moč (podobno Tezos).
- **Anonimnost**: Zero-knowledge votes za zasebnost, a transparentne uteži.
- **Skalabilnost**: L2 rešitve (npr. rollups) za tisoče tx/sekundo.
- **Governance**: Sistem sam glasuje o nadgradnjah (meta-glasovanje).

## **VI. IMPLEMENTACIJA IN TRANZICIJA**

1. **Razvoj**: Začni z testnetom na Ethereum Sepolia.
2. **Launch**: Airdrop začetnih identitet prek app.
3. **Integracija**: Poveži z obstoječimi DAOs (npr. Aragon za UI).
4. **Tranzicija**: Vzporedno z obstoječimi sistemi – uporabniki migrirajo, ko vidijo koristi (brez centralne korupcije).

> **Zaključek**: Ta DApp pretvori korupcijo v zaupanje. Glas ni več fiat – je delegiran in utežen po resnični vrednosti skupnosti.  
*(temelji na Cosmos SDK za custom chain.)*
