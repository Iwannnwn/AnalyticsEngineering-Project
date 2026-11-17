# Fintech Lending Analytics Engineering

**BigQuery · dbt · SQL · Python · Medallion Architecture**

> Dokumentasi proyek end-to-end untuk membangun data warehouse analitik dari dataset fintech lending Indonesia. Dokumen ini menjelaskan konteks domain, keputusan pemodelan, proses teknis, pengujian kualitas data, hasil analisis, dan keterbatasan interpretasi.

Repository: https://github.com/Iwannnwn/AnalyticsEngineering-Project

---

## 1. Project Background

### 1.1 Latar belakang bisnis

Layanan *fintech lending* mempertemukan pihak yang membutuhkan pembiayaan dengan penyedia dana melalui platform digital. Dalam konteks proyek ini, data merepresentasikan peminjam pada ekosistem **peer-to-peer (P2P) lending dan paylater** di Indonesia.

Pertumbuhan akses pembiayaan digital perlu diimbangi pemantauan kemampuan bayar. Dari sisi bisnis, perusahaan pembiayaan dan pengelola risiko perlu menjawab pertanyaan seperti:

- Berapa banyak borrower yang masih lancar dan berapa yang mengalami keterlambatan?
- Seberapa besar outstanding loan pada setiap kelompok status pembayaran?
- Apakah pemanfaatan limit kredit yang tinggi berhubungan dengan proporsi default yang lebih tinggi?
- Apakah beban cicilan bulanan relatif terhadap pendapatan dapat membantu mengidentifikasi kelompok berisiko?
- Kelompok borrower mana yang perlu diprioritaskan untuk pemantauan atau peninjauan risiko lebih lanjut?

Tujuan proyek ini adalah membangun alur data yang dapat diulang dan diuji, dari data mentah hingga tabel analitik yang menjawab pertanyaan tersebut. Fokusnya bukan membuat model prediksi machine learning, melainkan membangun **fondasi data analytics engineering** yang terstruktur, terdokumentasi, dan memiliki pemeriksaan kualitas.

### 1.2 Dataset

Dataset yang digunakan berjudul **Indonesia Fintech P2P Lending & Paylater Default Dynamics 2026** dan berisi:

| Karakteristik | Nilai |
|---|---:|
| Jumlah baris | 10.000 borrower |
| Jumlah kolom | 26 |
| Missing values pada pemeriksaan awal | 0 |
| Duplikasi baris identik | 0 |
| Duplikasi `borrower_id` | 0 |
| Rentang usia | 18–35 tahun |
| Rentang `days_past_due` | 0–180 hari |

Dataset memiliki satu baris per borrower pada snapshot yang dianalisis. Dataset tidak menyediakan dimensi waktu transaksi atau riwayat perubahan status borrower. Karena itu, hasil proyek menggambarkan **distribusi dan hubungan antarvariabel dalam snapshot**, bukan tren historis, cohort performance, atau monitoring perubahan status dari waktu ke waktu.

### 1.3 Kelompok data dan alasan relevansinya

| Kelompok | Kolom contoh | Relevansi analitik |
|---|---|---|
| Profil borrower | `age`, `gender`, `province`, `education_level`, `employment_status` | Memberikan konteks karakteristik borrower dan memungkinkan analisis segmentasi. |
| Kondisi finansial | `monthly_income_idr`, `regional_minimum_wage_umr_idr`, `debt_to_income_ratio`, `debt_service_ratio`, `disposable_income_after_debt_idr` | Membantu memahami pendapatan, kewajiban, dan ruang pendapatan yang tersisa. |
| Fasilitas pinjaman | `num_active_lending_apps`, `total_loan_outstanding_idr`, `credit_limit_granted_idr`, `loan_tenor_months`, `daily_interest_rate_pct`, `primary_loan_purpose` | Memberikan gambaran eksposur utang dan pola penggunaan fasilitas pembiayaan. |
| Risiko dan pembayaran | `days_past_due`, `twp90_default_status`, `financial_distress_index`, `primary_default_root_cause` | Menjadi dasar ringkasan kualitas pembayaran dan analisis risiko kredit. |
| Informasi tambahan | `cot_financial_psychology_rationale`, `confidence_score` | Menyimpan konteks tambahan dari dataset; definisi dan metodologi pembentukannya belum cukup terdokumentasi untuk dijadikan ukuran baku. |

Seluruh kolom dipertahankan pada layer staging agar data sumber tidak kehilangan informasi terlalu dini. Pemilihan kolom khusus kebutuhan analisis dilakukan pada Gold marts.

---

## 2. Domain Knowledge sebagai Landasan Analisis dan Data Tests

Bagian ini menjelaskan definisi yang digunakan dalam proyek. Definisi dibedakan antara **konsep domain umum** dan **operasionalisasi yang benar-benar diterapkan oleh dataset**. Pembedaan ini penting agar label kolom tidak dianggap otomatis mengikuti definisi industri atau regulasi tertentu.

### 2.1 DPD — Days Past Due

`days_past_due` menunjukkan jumlah hari keterlambatan pembayaran. Semakin besar DPD, semakin lama kewajiban pembayaran belum dipenuhi.

Pada dataset ini, rentang DPD konsisten dengan label status berikut:

| Status dalam dataset | Rentang DPD yang diharapkan | Interpretasi dalam proyek |
|---|---:|---|
| `Current-Performing` | 0 | Tidak tercatat terlambat. |
| `Special-Mention-DPD1-30` | 1–30 | Keterlambatan awal. |
| `Substandard-DPD31-60` | 31–60 | Keterlambatan berlanjut. |
| `Doubtful-DPD61-90` | 61–90 | Keterlambatan lebih panjang dan perlu perhatian. |
| `Default-Macet-TWP90` | 91–180 | Kelompok default menurut klasifikasi dataset. |

**Alasan data test:** status tidak boleh bertentangan dengan jumlah hari keterlambatan. Contohnya, borrower berstatus `Current-Performing` dengan DPD 45 merupakan inkonsistensi yang harus ditandai.

### 2.2 TWP90

TWP90 digunakan dalam konteks proyek sebagai indikator borrower yang masuk kategori keterlambatan lebih dari 90 hari. Secara operasional, dataset memberi label `Default-Macet-TWP90` untuk borrower dengan DPD 91–180.

Proyek menggunakan label dan rentang dari dataset sebagai klasifikasi analitik. Ini **tidak dimaksudkan sebagai pernyataan bahwa seluruh skema klasifikasi pada proyek merupakan definisi regulasi yang berlaku universal**. Untuk implementasi produksi, definisi TWP90 harus diselaraskan dengan kebijakan risiko, kontrak, dan ketentuan regulator yang berlaku bagi institusi terkait.

**Alasan analisis:** jumlah dan persentase borrower pada kategori TWP90 memberikan ringkasan ukuran kelompok default dalam snapshot. Outstanding pada kelompok tersebut membantu melihat besaran eksposur pinjaman yang terkait dengan kategori itu.

### 2.3 Outstanding loan dan credit limit

- `total_loan_outstanding_idr`: nilai kewajiban pinjaman yang masih outstanding menurut dataset.
- `credit_limit_granted_idr`: limit kredit yang diberikan.

Kedua nilai tersebut digunakan untuk menghitung pemanfaatan limit kredit. Keduanya tidak boleh bernilai negatif dalam konteks data ini.

**Alasan data test:** nilai finansial dasar negatif biasanya menunjukkan kesalahan data, kesalahan tanda, atau masalah proses pemuatan. Karena itu, `monthly_income_idr`, `total_loan_outstanding_idr`, `credit_limit_granted_idr`, dan `monthly_installment_estimate_idr` diuji agar tidak negatif.

### 2.4 Credit limit utilization ratio

Dalam dataset ini, rasio pemanfaatan limit dihitung sebagai:

\[
\text{Utilization} = \frac{\text{Total Loan Outstanding}}{\text{Credit Limit Granted}}
\]

Contoh: outstanding Rp8 juta dengan limit Rp10 juta menghasilkan utilization 0,80 atau 80%.

Nilai lebih dari 1 berarti outstanding lebih besar daripada limit yang tercatat. Kondisi tersebut tidak langsung dihapus atau dipaksa menjadi 1. Nilai itu dapat menjadi sinyal yang perlu ditelusuri, atau mencerminkan cara data disusun.

Segmentasi eksploratif yang digunakan:

| Segment | Aturan |
|---|---:|
| Low Utilization | `< 0.30` |
| Moderate Utilization | `0.30–<0.60` |
| High Utilization | `0.60–<0.80` |
| Very High Utilization | `>= 0.80` |

Ambang tersebut merupakan **cut-off analitik yang dipilih untuk eksplorasi proyek**, bukan batas risiko resmi atau universal.

**Alasan analisis dan test:** rasio diperiksa terhadap formula sumber agar nilainya konsisten. Segmentasi membantu membandingkan komposisi status pembayaran antarlevel pemanfaatan limit.

### 2.5 Debt service ratio (DSR)

Dalam proyek ini, `debt_service_ratio` sesuai dengan formula:

\[
\text{DSR} = \frac{\text{Monthly Installment Estimate}}{\text{Monthly Income}}
\]

DSR menggambarkan porsi pendapatan bulanan yang digunakan untuk estimasi cicilan. DSR 0,40 berarti estimasi cicilan setara 40% dari pendapatan bulanan. DSR lebih dari 1 berarti estimasi cicilan lebih besar daripada pendapatan bulanan.

Segmentasi yang digunakan pada `mart_credit_risk`:

| Segment | Aturan |
|---|---:|
| Low DSR | `< 0.30` |
| Moderate DSR | `0.30–<0.50` |
| High DSR | `0.50–<0.70` |
| Very High DSR | `>= 0.70` |

Cut-off ini adalah pengelompokan eksploratif proyek, bukan rekomendasi underwriting atau ambang regulasi.

**Alasan analisis:** DSR membantu membandingkan tingkat beban cicilan relatif terhadap pendapatan. Kombinasi DSR dan utilization digunakan untuk melihat apakah dua dimensi tekanan finansial tersebut secara bersama-sama membedakan tingkat default dalam dataset.

### 2.6 Income to UMR ratio

Formula yang terverifikasi pada dataset:

\[
\text{Income to UMR} = \frac{\text{Monthly Income}}{\text{Regional Minimum Wage (UMR)}}
\]

Rasio ini menunjukkan pendapatan borrower relatif terhadap nilai UMR yang tercatat untuk wilayahnya. Rasio 1,00 berarti pendapatan setara UMR pada dataset.

### 2.7 Debt to income ratio dalam dataset

Nama kolom `debt_to_income_ratio` pada dataset ini mengikuti formula yang terverifikasi:

\[
\text{Dataset DTI} = \frac{\text{Total Loan Outstanding}}{\text{Monthly Income}}
\]

Perlu diperhatikan bahwa formula ini menggunakan **total outstanding**, bukan cicilan atau total pembayaran utang periodik. Karena istilah DTI dapat didefinisikan berbeda dalam praktik keuangan, dokumentasi analitik harus selalu menjelaskan formula yang digunakan dan tidak menyamakan label kolom dengan definisi lain tanpa verifikasi.

### 2.8 Disposable income after debt

`disposable_income_after_debt_idr` adalah indikator sisa pendapatan setelah kewajiban yang diperhitungkan oleh dataset. Sebanyak 2.653 borrower (26,53%) memiliki nilai negatif.

Nilai negatif tidak otomatis dianggap kesalahan. Secara analitik, nilai ini dapat menunjukkan bahwa kewajiban atau pengeluaran yang diperhitungkan melampaui pendapatan. Namun, formula pembentuk kolom ini tidak divalidasi secara independen dalam proyek, sehingga nilai tersebut diperlakukan sebagai indikator yang disediakan dataset, bukan dihitung ulang atau digunakan sebagai dasar klaim kausal.

### 2.9 Financial distress index dan confidence score

`financial_distress_index` meningkat secara rata-rata pada kelompok status pembayaran yang lebih buruk dalam dataset. Namun, skala, formula, dan bobot pembentuk indeks belum didokumentasikan secara memadai. Karena itu:

- indeks digunakan sebagai atribut ringkasan deskriptif;
- angka indeks tidak ditafsirkan sebagai probabilitas default;
- tidak dibuat klaim bahwa indeks tersebut merupakan skor risiko resmi atau telah tervalidasi.

Hal yang sama berlaku untuk `confidence_score`. Nilai dalam dataset berada pada rentang 0,927–0,990, tetapi makna statistik dan proses kalibrasinya belum diketahui. Nilai ini tidak diperlakukan sebagai confidence interval atau probabilitas model.

### 2.10 Batas interpretasi domain

Dataset tidak memiliki timestamp historis borrower dan dokumentasi metodologi pembentukan seluruh variabel belum tersedia. Beberapa relasi dapat terbentuk karena formula atau aturan saat dataset dibuat. Oleh sebab itu:

1. Temuan dalam proyek adalah **asosiasi/deskripsi**, bukan bukti sebab-akibat.
2. Nilai dan pola tidak boleh langsung digeneralisasi ke seluruh industri fintech lending Indonesia.
3. Indikator yang saling terkait secara formula perlu diperiksa terhadap potensi circularity atau data leakage sebelum dipakai membangun model prediksi.
4. Penggunaan operasional memerlukan definisi bisnis, sumber data, dan validasi domain dari pemilik proses.

---

## 3. Project Objectives dan Pertanyaan Analitik

### 3.1 Tujuan engineering

- Memuat dataset lokal ke BigQuery sebagai raw source table.
- Membuat transformasi yang dapat direproduksi menggunakan dbt.
- Memisahkan raw, staging, dan analytical marts sesuai Medallion Architecture.
- Menerapkan data quality tests untuk identitas borrower, status pembayaran, nilai finansial, dan konsistensi rasio.
- Menyediakan tabel Gold yang siap digunakan untuk dashboard atau ad hoc analytics.

### 3.2 Pertanyaan analitik

| Mart | Pertanyaan bisnis |
|---|---|
| `mart_twp90_monitoring` | Bagaimana distribusi status pembayaran, rata-rata DPD, dan outstanding pada tiap status? |
| `mart_borrower_segmentation` | Bagaimana komposisi status pembayaran pada tiap kelompok credit utilization? |
| `mart_credit_risk` | Bagaimana proporsi default pada kombinasi debt service ratio dan credit utilization? |

---

## 4. Technology Stack

| Teknologi | Peran |
|---|---|
| Python 3.11 | Profiling, validasi awal, dan ingestion data. |
| pandas | Membaca CSV dan menyiapkan DataFrame. |
| Google Cloud BigQuery | Cloud data warehouse untuk raw, staging, dan Gold tables. |
| Google Cloud SDK (`gcloud`, `bq`) | Autentikasi dan akses lingkungan Google Cloud. |
| dbt Core 1.12.7 | Pengelolaan SQL transformations, dependencies, tests, dan dokumentasi. |
| dbt-bigquery 1.12.3 | Adapter dbt untuk BigQuery. |
| SQL / BigQuery SQL | Transformasi dan analisis data. |
| Git dan GitHub | Version control dan publikasi kode proyek. |

Konfigurasi BigQuery proyek:

| Item | Nilai |
|---|---|
| GCP Project ID | `fintech-analytics-engineering` |
| Raw dataset | `fintech_raw` |
| Staging dataset | `fintech_staging` |
| Gold dataset | `fintech_marts` |
| BigQuery location | `asia-southeast2` |
| Raw table | `borrower_data` |

---

## 5. Data Warehouse Architecture

### 5.1 Medallion Architecture

Proyek menggunakan tiga layer utama:

```text
Local CSV
   |
   v
Python ingestion (pandas + google-cloud-bigquery)
   |
   v
BRONZE — BigQuery: fintech_raw.borrower_data
   |     Raw source table; data dimuat tanpa business transformation.
   |
   v
SILVER — dbt: fintech_staging.stg_borrowers
   |     Source declaration, explicit column selection, data contract,
   |     dan quality tests.
   |
   +----------------------+----------------------+
   |                      |                      |
   v                      v                      v
GOLD                  GOLD                  GOLD
mart_twp90_           mart_borrower_        mart_credit_
monitoring            segmentation          risk
   |                      |                      |
   +----------------------+----------------------+
                          |
                          v
            Dashboard / Ad hoc Analytics
```

### 5.2 Bronze layer

**Lokasi:** `fintech_raw.borrower_data`

Bronze berisi data hasil ingestion dari CSV ke BigQuery. Tabel ini menjadi source of truth untuk transformasi dbt. Tidak ada segmentasi bisnis atau agregasi Gold pada layer ini.

Keputusan teknis ingestion:

- CSV dibaca menggunakan pandas.
- DataFrame dikirim menggunakan `load_table_from_dataframe`.
- Schema dideteksi otomatis (`autodetect=True`).
- `WRITE_TRUNCATE` digunakan agar eksekusi ulang mengganti isi tabel, bukan menggandakan data.
- Jumlah baris dan kolom pada tabel tujuan diperiksa setelah job selesai.

**Catatan:** `WRITE_TRUNCATE` cocok untuk proses full refresh pada dataset latihan ini. Untuk sumber data bertambah setiap hari, ingestion perlu dirancang ulang menjadi incremental atau berbasis batch dengan primary key dan watermark yang jelas.

### 5.3 Silver layer

**Lokasi:** `fintech_staging.stg_borrowers`

Silver adalah model staging yang mengacu pada source Bronze. Model ini memilih 26 kolom secara eksplisit dan belum mengagregasi data.

Alasan tidak menggunakan `SELECT *`:

- perubahan schema sumber tidak otomatis menyebar tanpa disadari;
- daftar kolom yang dipakai menjadi eksplisit dan mudah ditinjau;
- kontrak model lebih stabil bagi downstream marts;
- memudahkan review perubahan dan dampak kolom.

Model staging dikonfigurasi sebagai **view** agar tidak membuat salinan fisik tambahan untuk setiap staging transformation.

### 5.4 Gold layer

**Lokasi:** `fintech_marts`

Gold berisi tabel agregasi yang dirancang berdasarkan pertanyaan bisnis. Ketiga model dimaterialisasi sebagai **table** agar hasil agregasi tersedia sebagai tabel analitik yang dapat digunakan berulang.

| Model | Grain (satu baris mewakili) | Fokus |
|---|---|---|
| `mart_twp90_monitoring` | Satu kategori status pembayaran | Distribusi borrower, DPD, outstanding, distress index. |
| `mart_borrower_segmentation` | Satu utilization segment | Profil segmen dan distribusi lima status pembayaran. |
| `mart_credit_risk` | Satu kombinasi DSR segment × utilization segment | Default count, default percentage, dan rata-rata indikator risiko. |

Grain penting untuk mencegah salah agregasi. Contohnya, satu baris di `mart_credit_risk` bukan satu borrower, melainkan satu kombinasi dua segmen.

### 5.5 dbt schema configuration

Potongan konfigurasi `dbt_project.yml`:

```yaml
models:
  fintech_analytics:
    staging:
      +schema: fintech_staging
      +materialized: view
    marts:
      +schema: fintech_marts
      +materialized: table
```

Macro `generate_schema_name.sql` digunakan agar custom schema dipakai persis sesuai nama yang didefinisikan, tanpa prefix schema target default dbt:

```sql
{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}
```

Tanpa penyesuaian ini, perilaku default dbt dapat menggabungkan schema target dengan custom schema. Macro di atas membuat staging dan marts diarahkan langsung ke `fintech_staging` dan `fintech_marts`.

### 5.6 dbt source declaration

File `models/staging/sources.yml`:

```yaml
version: 2

sources:
  - name: fintech_raw
    database: fintech-analytics-engineering
    schema: fintech_raw
    tables:
      - name: borrower_data
```

Deklarasi source memberi nama logis bagi tabel raw. Model SQL dapat memanggilnya melalui `source()` sehingga dependency tercatat dalam dbt lineage.

---

## 6. Data Ingestion dengan Python

Script: `scripts/ingest_to_bigquery.py`

Implementasi inti:

```python
from pathlib import Path
import pandas as pd
from google.cloud import bigquery

PROJECT_ID = "fintech-analytics-engineering"
DATASET_ID = "fintech_raw"
TABLE_ID = "borrower_data"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = PROJECT_ROOT / "data" / "raw" / "fintech_dataset.csv"
FULL_TABLE_ID = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"


def main():
    if not DATA_PATH.exists():
        raise FileNotFoundError(f"Dataset not found: {DATA_PATH}")

    df = pd.read_csv(DATA_PATH)

    client = bigquery.Client(project=PROJECT_ID)

    job_config = bigquery.LoadJobConfig(
        autodetect=True,
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )

    job = client.load_table_from_dataframe(
        df,
        FULL_TABLE_ID,
        job_config=job_config,
    )
    job.result()

    table = client.get_table(FULL_TABLE_ID)

    if table.num_rows != len(df):
        raise ValueError(
            f"Row count mismatch: source={len(df)}, destination={table.num_rows}"
        )


if __name__ == "__main__":
    main()
```

### Penjelasan implementasi

1. `Path(__file__)` digunakan agar lokasi file sumber ditentukan relatif terhadap lokasi script, bukan bergantung pada current working directory terminal.
2. Pemeriksaan `DATA_PATH.exists()` menghentikan proses lebih awal jika file tidak ditemukan.
3. `pd.read_csv()` memuat file sumber sebagai DataFrame.
4. `bigquery.Client()` menggunakan kredensial Google Cloud yang sudah dikonfigurasi pada environment.
5. `load_table_from_dataframe()` mengirimkan DataFrame ke BigQuery.
6. `job.result()` menunggu job ingestion selesai dan memunculkan error jika job gagal.
7. `get_table()` membaca metadata tabel tujuan; jumlah baris dibandingkan dengan sumber.

`source_format=PARQUET` digunakan pada job config untuk jalur pemuatan DataFrame. File input lokal tetap CSV yang dibaca oleh pandas.

### Autentikasi

Pengembangan dilakukan menggunakan autentikasi OAuth/Google Application Default Credentials. File credential dan konfigurasi lokal tidak boleh dimasukkan ke repository. Pada environment baru, autentikasi perlu dilakukan kembali oleh pemilik akun yang memiliki akses ke project BigQuery.

---

## 7. Profiling dan Validasi Awal Data

Dua script awal digunakan sebelum membangun transformasi dbt:

- `scripts/profile_data.py`: memeriksa ukuran data, tipe kolom, missing values, duplikasi baris, dan distribusi kolom.
- `scripts/validate_data.py`: memeriksa uniqueness borrower, rentang nilai, kategori, dan konsistensi dasar.

### 7.1 Hasil profiling

| Pemeriksaan | Hasil |
|---|---:|
| Row count | 10.000 |
| Column count | 26 |
| Missing values | 0 |
| Duplicate rows | 0 |
| Duplicate borrower IDs | 0 |
| Borrower ID unik | 10.000 |

### 7.2 Pemeriksaan rentang

| Kolom | Minimum | Maksimum |
|---|---:|---:|
| `age` | 18 | 35 |
| `monthly_income_idr` | Rp1.500.000 | Rp28.000.000 |
| `total_loan_outstanding_idr` | Rp510.000 | Rp65.000.000 |
| `credit_limit_granted_idr` | Rp1.890.000 | Rp80.000.000 |
| `days_past_due` | 0 | 180 |
| `confidence_score` | 0,927 | 0,990 |

Pemeriksaan awal juga tidak menemukan usia di bawah 18, pendapatan negatif, outstanding negatif, DPD negatif, atau confidence score di luar rentang 0–1.

### 7.3 Rasio yang ditemukan

| Rasio | Minimum | Maksimum | Rata-rata |
|---|---:|---:|---:|
| `debt_to_income_ratio` | 0,25 | 5,07 | 1,5888 |
| `income_to_umr_ratio` | 0,60 | 6,15 | 1,9452 |
| `credit_limit_utilization_ratio` | 0,1995 | 1,2492 | 0,5935 |
| `debt_service_ratio` | 0,0327 | 5,3506 | 0,8164 |

Rasio lebih dari 1 tidak otomatis dianggap invalid. Maknanya bergantung pada pembilang, penyebut, dan konteks domain masing-masing rasio.

---

## 8. Silver Transformation

File: `models/staging/stg_borrowers.sql`

```sql
SELECT
    borrower_id,
    age,
    gender,
    province,
    education_level,
    employment_status,
    monthly_income_idr,
    regional_minimum_wage_umr_idr,
    num_active_lending_apps,
    total_loan_outstanding_idr,
    credit_limit_granted_idr,
    loan_tenor_months,
    daily_interest_rate_pct,
    primary_loan_purpose,
    debt_to_income_ratio,
    income_to_umr_ratio,
    credit_limit_utilization_ratio,
    monthly_installment_estimate_idr,
    debt_service_ratio,
    disposable_income_after_debt_idr,
    days_past_due,
    financial_distress_index,
    twp90_default_status,
    primary_default_root_cause,
    cot_financial_psychology_rationale,
    confidence_score
FROM {{ source('fintech_raw', 'borrower_data') }}
```

Model ini sengaja tidak melakukan segmentasi atau agregasi. Perannya membentuk layer standar yang menjadi dependency bersama bagi tiga Gold marts.

### 8.1 Generic data tests pada staging

File: `models/staging/schema.yml`

```yaml
version: 2

models:
  - name: stg_borrowers
    description: "Staging model containing standardized borrower-level fintech lending data."

    columns:
      - name: borrower_id
        description: "Unique identifier for each borrower."
        data_tests:
          - not_null
          - unique

      - name: twp90_default_status
        description: "Borrower repayment status based on days past due."
        data_tests:
          - not_null
          - accepted_values:
              arguments:
                values:
                  - Current-Performing
                  - Special-Mention-DPD1-30
                  - Substandard-DPD31-60
                  - Doubtful-DPD61-90
                  - Default-Macet-TWP90
```

Landasan test:

- `borrower_id` harus terisi karena menjadi identitas record.
- `borrower_id` harus unik karena grain staging adalah satu record per borrower.
- status pembayaran wajib terisi agar borrower dapat diklasifikasikan.
- status harus termasuk kategori yang diketahui; salah ketik atau kategori tak terdefinisi perlu ditinjau.

---

## 9. dbt Data Quality Tests

dbt generic tests didefinisikan di YAML. Singular tests ditulis sebagai query SQL yang mengembalikan **baris yang gagal memenuhi aturan**. Jika query mengembalikan nol baris, test dinyatakan PASS.

Total test yang terdaftar dan berhasil dijalankan dalam proyek: **28 tests**.

| Area | Generic tests | Singular tests | Total |
|---|---:|---:|---:|
| Staging | 4 | 3 | 7 |
| `mart_twp90_monitoring` | 5 | 1 | 6 |
| `mart_borrower_segmentation` | 6 | 1 | 7 |
| `mart_credit_risk` | 7 | 1 | 8 |
| **Total** | **22** | **6** | **28** |

### 9.1 Generic tests

| Test | Fungsi | Alasan domain |
|---|---|---|
| `not_null` | Memastikan kolom tidak kosong. | Identitas, status, dan metrik utama dibutuhkan untuk klasifikasi serta agregasi. |
| `unique` | Memastikan tidak ada nilai duplikat pada kolom yang diuji. | `borrower_id` harus unik pada grain borrower; segmen status pada mart status juga harus satu baris per kategori. |
| `accepted_values` | Membatasi nilai pada daftar kategori yang disetujui. | Mencegah status atau label segmen di luar definisi model. |

Contoh deklarasi generic test:

```yaml
data_tests:
  - not_null
  - unique
  - accepted_values:
      arguments:
        values:
          - Current-Performing
          - Special-Mention-DPD1-30
          - Substandard-DPD31-60
          - Doubtful-DPD61-90
          - Default-Macet-TWP90
```

### 9.2 Singular test: konsistensi DPD dan status

File: `tests/assert_borrower_dpd_status_consistency.sql`

```sql
SELECT
    borrower_id,
    days_past_due,
    twp90_default_status

FROM {{ ref('stg_borrowers') }}

WHERE
    CASE
        WHEN twp90_default_status = 'Current-Performing'
            THEN days_past_due = 0
        WHEN twp90_default_status = 'Special-Mention-DPD1-30'
            THEN days_past_due BETWEEN 1 AND 30
        WHEN twp90_default_status = 'Substandard-DPD31-60'
            THEN days_past_due BETWEEN 31 AND 60
        WHEN twp90_default_status = 'Doubtful-DPD61-90'
            THEN days_past_due BETWEEN 61 AND 90
        WHEN twp90_default_status = 'Default-Macet-TWP90'
            THEN days_past_due BETWEEN 91 AND 180
        ELSE FALSE
    END IS NOT TRUE
```

**Mengapa test ini diperlukan?** Status adalah klasifikasi turunan dari perilaku keterlambatan pada dataset. Jika status dan DPD tidak sejalan, agregasi TWP90 dapat menghasilkan kesimpulan yang salah.

`IS NOT TRUE` menangkap kondisi FALSE maupun NULL. Hal ini membuat ekspresi lebih ketat dibanding hanya memfilter `= FALSE`.

### 9.3 Singular test: nilai finansial tidak negatif

File: `tests/assert_non_negative_financial_values.sql`

```sql
SELECT
    borrower_id,
    monthly_income_idr,
    total_loan_outstanding_idr,
    credit_limit_granted_idr,
    monthly_installment_estimate_idr
FROM {{ ref('stg_borrowers') }}
WHERE
    monthly_income_idr < 0
    OR total_loan_outstanding_idr < 0
    OR credit_limit_granted_idr < 0
    OR monthly_installment_estimate_idr < 0
```

**Mengapa kolom ini diuji?** Pendapatan, outstanding, limit, dan estimasi cicilan merupakan nilai nominal dasar yang tidak diharapkan negatif dalam konteks dataset ini. Nilai negatif perlu ditinjau sebelum analisis rasio dilakukan.

`disposable_income_after_debt_idr` tidak dimasukkan karena nilai negatif dapat memiliki makna bisnis: kewajiban atau pengeluaran yang diperhitungkan mungkin lebih besar daripada pendapatan. Nilai negatifnya tidak otomatis merupakan kesalahan data.

### 9.4 Singular test: konsistensi formula rasio

File: `tests/assert_financial_ratios_consistency.sql`

```sql
SELECT borrower_id
FROM {{ ref('stg_borrowers') }}
WHERE
    ABS(
        income_to_umr_ratio -
        SAFE_DIVIDE(monthly_income_idr, regional_minimum_wage_umr_idr)
    ) > 0.01
    OR ABS(
        debt_to_income_ratio -
        SAFE_DIVIDE(total_loan_outstanding_idr, monthly_income_idr)
    ) > 0.01
    OR ABS(
        credit_limit_utilization_ratio -
        SAFE_DIVIDE(total_loan_outstanding_idr, credit_limit_granted_idr)
    ) > 0.01
    OR ABS(
        debt_service_ratio -
        SAFE_DIVIDE(monthly_installment_estimate_idr, monthly_income_idr)
    ) > 0.01
```

**Mengapa test ini diperlukan?** Keempat rasio digunakan untuk analisis dan segmentasi. Test memastikan nilai rasio yang disediakan dataset sesuai dengan formula yang teramati.

- `SAFE_DIVIDE()` menghindari error pembagian dengan nol; hasil pembagian yang tidak valid menjadi NULL.
- `ABS()` menghitung selisih absolut.
- Toleransi `0.01` digunakan karena nilai rasio pada sumber telah dibulatkan.

Test ini memvalidasi konsistensi dengan formula dataset, bukan menyatakan bahwa nama atau formula tersebut adalah satu-satunya definisi yang berlaku di industri. Jika kelak kolom sumber dapat bernilai NULL, tambahkan `not_null` atau validasi denominator agar NULL tidak luput dari pemeriksaan.

---

## 10. Gold Data Marts: Implementasi dan Hasil

### 10.1 Mart 1 — `mart_twp90_monitoring`

**Grain:** satu baris untuk setiap kategori `twp90_default_status`.

Tujuan model adalah meringkas distribusi status, rata-rata dan maksimum DPD, rata-rata outstanding, total outstanding, serta rata-rata distress index.

SQL utama:

```sql
WITH borrower_summary AS (
    SELECT
        twp90_default_status,
        COUNT(*) AS total_borrowers,
        AVG(days_past_due) AS avg_days_past_due,
        MAX(days_past_due) AS max_days_past_due,
        AVG(total_loan_outstanding_idr) AS avg_outstanding_idr,
        SUM(total_loan_outstanding_idr) AS total_outstanding_idr,
        AVG(financial_distress_index) AS avg_financial_distress_index
    FROM {{ ref('stg_borrowers') }}
    GROUP BY twp90_default_status
)
SELECT
    twp90_default_status,
    total_borrowers,
    ROUND(
        SAFE_DIVIDE(
            total_borrowers * 100.0,
            SUM(total_borrowers) OVER ()
        ),
        2
    ) AS borrower_percentage,
    ROUND(avg_days_past_due, 2) AS avg_days_past_due,
    max_days_past_due,
    ROUND(avg_outstanding_idr, 2) AS avg_outstanding_idr,
    total_outstanding_idr,
    ROUND(avg_financial_distress_index, 4) AS avg_financial_distress_index
FROM borrower_summary
```

Konsep SQL yang digunakan:

- `COUNT(*)`: jumlah borrower per status.
- `AVG()` dan `MAX()`: ringkasan DPD serta indikator finansial.
- `SUM()`: total outstanding per status.
- `GROUP BY`: menghasilkan satu row per status.
- `SUM(...) OVER ()`: menghitung total borrower lintas status tanpa menghilangkan grain hasil agregasi.
- `SAFE_DIVIDE()`: menghitung persentase dengan aman.
- `ROUND()`: membatasi presisi tampilan.

Hasil:

| Status | Borrowers | Share | Avg DPD | Max DPD | Avg outstanding | Total outstanding | Avg distress index |
|---|---:|---:|---:|---:|---:|---:|---:|
| Current-Performing | 3.508 | 35,08% | 0,00 | 0 | Rp5.941.502 | Rp20.842.790.000 | 3,0026 |
| Special-Mention-DPD1-30 | 1.731 | 17,31% | 17,21 | 30 | Rp8.559.867 | Rp14.817.130.000 | 4,0924 |
| Substandard-DPD31-60 | 1.367 | 13,67% | 44,59 | 60 | Rp9.936.920 | Rp13.583.770.000 | 4,7443 |
| Doubtful-DPD61-90 | 856 | 8,56% | 74,66 | 90 | Rp11.325.234 | Rp9.694.400.000 | 5,3533 |
| Default-Macet-TWP90 | 2.538 | 25,38% | 142,97 | 180 | Rp15.791.099 | Rp40.077.810.000 | 7,3288 |

**Ringkasan:** 25,38% borrower berada pada kategori `Default-Macet-TWP90`. Kelompok ini memiliki rata-rata outstanding dan distress index tertinggi di antara status yang ditampilkan. Angka tersebut adalah ringkasan snapshot, bukan prediksi default di masa depan.

#### dbt tests untuk mart 1

Generic tests:

- `twp90_default_status`: `not_null`, `unique`, `accepted_values` untuk lima status.
- `total_borrowers`: `not_null`.
- `borrower_percentage`: `not_null`.

Singular test: `tests/assert_twp90_monitoring_aggregation.sql`

```sql
WITH source_summary AS (
    SELECT twp90_default_status, COUNT(*) AS total_borrowers
    FROM {{ ref('stg_borrowers') }}
    GROUP BY twp90_default_status
)
SELECT
    gold.twp90_default_status,
    gold.total_borrowers,
    source.total_borrowers AS expected_borrowers
FROM {{ ref('mart_twp90_monitoring') }} AS gold
LEFT JOIN source_summary AS source
    ON gold.twp90_default_status = source.twp90_default_status
WHERE
    source.total_borrowers IS NULL
    OR gold.total_borrowers != source.total_borrowers
```

Test ini membandingkan jumlah borrower tiap status pada Gold dengan perhitungan ulang langsung dari staging. Tujuannya mendeteksi kategori yang hilang atau jumlah agregat yang berubah karena kesalahan transformasi.

**Hasil test mart 1:** 6 PASS (5 generic + 1 singular).

### 10.2 Mart 2 — `mart_borrower_segmentation`

**Grain:** satu baris untuk setiap utilization segment.

Model mengelompokkan borrower berdasarkan `credit_limit_utilization_ratio`, kemudian menghitung profil finansial rata-rata dan komposisi status pembayaran di setiap segmen.

SQL utama:

```sql
WITH borrower_segmentation AS (
    SELECT
        borrower_id,
        monthly_income_idr,
        total_loan_outstanding_idr,
        credit_limit_utilization_ratio,
        debt_service_ratio,
        financial_distress_index,
        twp90_default_status,
        CASE
            WHEN credit_limit_utilization_ratio < 0.30
                THEN 'Low Utilization'
            WHEN credit_limit_utilization_ratio < 0.60
                THEN 'Moderate Utilization'
            WHEN credit_limit_utilization_ratio < 0.80
                THEN 'High Utilization'
            ELSE 'Very High Utilization'
        END AS utilization_segment
    FROM {{ ref('stg_borrowers') }}
),
segment_summary AS (
    SELECT
        utilization_segment,
        COUNT(*) AS total_borrowers,
        AVG(credit_limit_utilization_ratio) AS avg_utilization,
        AVG(monthly_income_idr) AS avg_monthly_income_idr,
        AVG(total_loan_outstanding_idr) AS avg_outstanding_idr,
        AVG(debt_service_ratio) AS avg_dsr,
        AVG(financial_distress_index) AS avg_distress_index,
        COUNTIF(twp90_default_status = 'Current-Performing') AS current_borrowers,
        COUNTIF(twp90_default_status = 'Special-Mention-DPD1-30') AS special_mention_borrowers,
        COUNTIF(twp90_default_status = 'Substandard-DPD31-60') AS substandard_borrowers,
        COUNTIF(twp90_default_status = 'Doubtful-DPD61-90') AS doubtful_borrowers,
        COUNTIF(twp90_default_status = 'Default-Macet-TWP90') AS default_borrowers
    FROM borrower_segmentation
    GROUP BY utilization_segment
)
SELECT
    utilization_segment,
    total_borrowers,
    ROUND(avg_utilization, 3) AS avg_utilization,
    ROUND(avg_monthly_income_idr, 2) AS avg_monthly_income_idr,
    ROUND(avg_outstanding_idr, 2) AS avg_outstanding_idr,
    ROUND(avg_dsr, 2) AS avg_dsr,
    ROUND(avg_distress_index, 2) AS avg_distress_index,
    ROUND(SAFE_DIVIDE(current_borrowers * 100.0, total_borrowers), 2) AS current_percentage,
    ROUND(SAFE_DIVIDE(special_mention_borrowers * 100.0, total_borrowers), 2) AS special_mention_percentage,
    ROUND(SAFE_DIVIDE(substandard_borrowers * 100.0, total_borrowers), 2) AS substandard_percentage,
    ROUND(SAFE_DIVIDE(doubtful_borrowers * 100.0, total_borrowers), 2) AS doubtful_percentage,
    ROUND(SAFE_DIVIDE(default_borrowers * 100.0, total_borrowers), 2) AS default_percentage
FROM segment_summary
```

Konsep SQL yang digunakan:

- `CASE WHEN`: membuat segmentasi bisnis eksplisit.
- `COUNTIF()`: menghitung jumlah borrower untuk setiap status tanpa membuat beberapa query terpisah.
- `AVG()`: membandingkan profil pendapatan, outstanding, DSR, utilization, dan distress index.
- `SAFE_DIVIDE()`: menghitung persentase tiap status terhadap total borrower dalam segmen.

Hasil:

| Utilization segment | Borrowers | Avg utilization | Avg income | Avg outstanding | Avg DSR | Avg distress | Default borrowers | Default rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Low Utilization | 1.155 | 0,249 | Rp6.279.879 | Rp4.171.991 | 0,33 | 2,30 | 0 | 0,00% |
| Moderate Utilization | 4.456 | 0,459 | Rp6.258.701 | Rp7.612.830 | 0,62 | 3,66 | 284 | 6,37% |
| High Utilization | 2.162 | 0,681 | Rp6.231.739 | Rp11.479.505 | 0,95 | 5,18 | 505 | 23,36% |
| Very High Utilization | 2.227 | 0,957 | Rp6.240.687 | Rp15.920.876 | 1,33 | 7,67 | 1.749 | 78,54% |

Distribusi seluruh status di dalam setiap segmen:

| Utilization segment | Current | Special Mention | Substandard | Doubtful | Default |
|---|---:|---:|---:|---:|---:|
| Low | 82,51% | 13,59% | 3,29% | 0,61% | 0,00% |
| Moderate | 47,55% | 23,23% | 15,48% | 7,36% | 6,37% |
| High | 18,78% | 21,18% | 22,34% | 14,34% | 23,36% |
| Very High | 1,35% | 3,64% | 7,00% | 9,47% | 78,54% |

**Ringkasan:** default rate meningkat seiring kategori utilization dalam dataset ini. Pada kelompok Very High Utilization, 78,54% borrower masuk kategori default. Rata-rata pendapatan antarkelompok relatif mirip, sedangkan outstanding, DSR, dan distress index rata-rata meningkat pada kelompok utilization yang lebih tinggi.

Temuan ini menunjukkan asosiasi yang kuat dalam dataset. Temuan tidak membuktikan bahwa peningkatan utilization dengan sendirinya menyebabkan default.

#### dbt tests untuk mart 2

Generic tests:

- `utilization_segment`: `not_null`, `unique`, `accepted_values` untuk empat label.
- `total_borrowers`: `not_null`.
- `default_percentage`: `not_null`.
- `avg_utilization`: `not_null`.

Singular test: `tests/assert_borrower_segmentation_distribution.sql`

```sql
SELECT
    utilization_segment,
    (
        current_percentage
        + special_mention_percentage
        + substandard_percentage
        + doubtful_percentage
        + default_percentage
    ) AS total_status_percentage
FROM {{ ref('mart_borrower_segmentation') }}
WHERE ABS(
    (
        current_percentage
        + special_mention_percentage
        + substandard_percentage
        + doubtful_percentage
        + default_percentage
    ) - 100
) > 0.02
```

**Mengapa test ini diperlukan?** Setiap borrower dalam segmen harus berada tepat pada satu dari lima status. Karena model mengubah jumlah status menjadi persentase, total kelima persentase di setiap segmen harus mendekati 100%. Toleransi 0,02 percentage point digunakan karena persentase dibulatkan menjadi dua desimal.

**Hasil test mart 2:** 7 PASS (6 generic + 1 singular).

### 10.3 Mart 3 — `mart_credit_risk`

**Grain:** satu baris untuk setiap kombinasi `dsr_segment` dan `utilization_segment`.

Model ini menggabungkan dua dimensi tekanan finansial:

1. DSR sebagai rasio estimasi cicilan bulanan terhadap pendapatan.
2. Credit utilization sebagai rasio outstanding terhadap limit kredit.

SQL utama:

```sql
WITH borrower_risk AS (
    SELECT
        borrower_id,
        debt_service_ratio,
        credit_limit_utilization_ratio,
        financial_distress_index,
        twp90_default_status,
        CASE
            WHEN debt_service_ratio < 0.30
                THEN 'Low DSR'
            WHEN debt_service_ratio < 0.50
                THEN 'Moderate DSR'
            WHEN debt_service_ratio < 0.70
                THEN 'High DSR'
            ELSE 'Very High DSR'
        END AS dsr_segment,
        CASE
            WHEN credit_limit_utilization_ratio < 0.30
                THEN 'Low Utilization'
            WHEN credit_limit_utilization_ratio < 0.60
                THEN 'Moderate Utilization'
            WHEN credit_limit_utilization_ratio < 0.80
                THEN 'High Utilization'
            ELSE 'Very High Utilization'
        END AS utilization_segment
    FROM {{ ref('stg_borrowers') }}
),
risk_summary AS (
    SELECT
        dsr_segment,
        utilization_segment,
        COUNT(*) AS total_borrowers,
        COUNTIF(twp90_default_status = 'Default-Macet-TWP90') AS default_borrowers,
        AVG(debt_service_ratio) AS avg_dsr,
        AVG(credit_limit_utilization_ratio) AS avg_utilization,
        AVG(financial_distress_index) AS avg_distress_index
    FROM borrower_risk
    GROUP BY dsr_segment, utilization_segment
)
SELECT
    dsr_segment,
    utilization_segment,
    total_borrowers,
    default_borrowers,
    ROUND(
        SAFE_DIVIDE(default_borrowers * 100.0, total_borrowers),
        2
    ) AS default_percentage,
    ROUND(avg_dsr, 3) AS avg_dsr,
    ROUND(avg_utilization, 3) AS avg_utilization,
    ROUND(avg_distress_index, 2) AS avg_distress_index
FROM risk_summary
```

Konsep SQL yang digunakan:

- dua `CASE WHEN` membuat dua dimensi segmentasi;
- `GROUP BY dsr_segment, utilization_segment` menghasilkan kombinasi segmen;
- `COUNTIF()` menghitung borrower yang berstatus default;
- `SAFE_DIVIDE()` menghasilkan default percentage;
- `AVG()` menyajikan nilai rata-rata aktual dalam kombinasi tersebut.

Hasil keseluruhan:

| Metric | Hasil |
|---|---:|
| Jumlah kombinasi segmen | 16 |
| Total borrower | 10.000 |
| Total default borrower | 2.538 |
| Overall default percentage | 25,38% |

Tabel kombinasi DSR × utilization. Isi setiap sel adalah **jumlah default / jumlah borrower (default rate)**:

| DSR segment | Low Utilization | Moderate Utilization | High Utilization | Very High Utilization |
|---|---:|---:|---:|---:|
| Low DSR | 0 / 705 (0,00%) | 0 / 1.537 (0,00%) | 6 / 350 (1,71%) | 25 / 143 (17,48%) |
| Moderate DSR | 0 / 208 (0,00%) | 0 / 1.031 (0,00%) | 10 / 463 (2,16%) | 165 / 324 (50,93%) |
| High DSR | 0 / 95 (0,00%) | 1 / 517 (0,19%) | 17 / 322 (5,28%) | 250 / 347 (72,05%) |
| Very High DSR | 0 / 147 (0,00%) | 283 / 1.371 (20,64%) | 472 / 1.027 (45,96%) | 1.309 / 1.413 (92,64%) |

**Temuan utama:** kombinasi Very High DSR dan Very High Utilization memiliki default rate tertinggi, yaitu 92,64% (1.309 dari 1.413 borrower). Kelompok Very High DSR dengan High Utilization memiliki default rate 45,96%, sedangkan High DSR dengan Very High Utilization sebesar 72,05%.

Temuan ini memperlihatkan bahwa kombinasi indikator dapat memberi pemisahan yang lebih detail daripada melihat DSR atau utilization secara terpisah. Namun, hasil pada kombinasi dengan populasi kecil harus ditafsirkan hati-hati. Hubungan tersebut juga belum membuktikan kausalitas.

#### dbt tests untuk mart 3

Generic tests:

- `dsr_segment`: `not_null`, `accepted_values` untuk empat label DSR.
- `utilization_segment`: `not_null`, `accepted_values` untuk empat label utilization.
- `total_borrowers`: `not_null`.
- `default_borrowers`: `not_null`.
- `default_percentage`: `not_null`.

Singular test: `tests/assert_credit_risk_unique_segments.sql`

```sql
SELECT
    dsr_segment,
    utilization_segment,
    COUNT(*) AS total_records
FROM {{ ref('mart_credit_risk') }}
GROUP BY
    dsr_segment,
    utilization_segment
HAVING COUNT(*) > 1
```

**Mengapa test ini diperlukan?** Grain model didefinisikan sebagai satu baris per kombinasi DSR dan utilization. Duplikasi kombinasi berarti grain dilanggar dan dapat menyebabkan penghitungan ganda saat mart digunakan.

**Hasil test mart 3:** 8 PASS (7 generic + 1 singular).

---

## 11. Hasil Analisis Tambahan

### 11.1 Negative disposable income

Ditemukan 2.653 borrower (26,53%) dengan `disposable_income_after_debt_idr` negatif.

Proporsi nilai negatif berdasarkan status:

| Status | Borrowers dengan disposable income negatif | Proporsi dalam status |
|---|---:|---:|
| Default-Macet-TWP90 | 1.720 / 2.538 | 67,77% |
| Doubtful-DPD61-90 | 448 / 856 | 52,34% |
| Substandard-DPD31-60 | 348 / 1.367 | 25,46% |
| Special-Mention-DPD1-30 | 121 / 1.731 | 6,99% |
| Current-Performing | 16 / 3.508 | 0,46% |

**Interpretasi:** nilai disposable income negatif lebih banyak ditemukan pada kelompok status pembayaran yang lebih buruk. Hasil ini bersifat deskriptif. Formula disposable income dan kemungkinan keterkaitannya dengan proses pembentukan status perlu divalidasi sebelum digunakan sebagai faktor penyebab.

### 11.2 Employment status dan income quartile

Eksplorasi awal memperlihatkan bahwa persentase default antarkelompok employment status relatif berdekatan, sekitar 23,98%–25,78%. Pembagian pendapatan menjadi empat kuartil juga menghasilkan default percentage yang relatif mirip, sekitar 24,84%–25,76%.

Karena pemisahan default pada dua pendekatan ini tidak terlalu kuat dalam dataset, proyek memprioritaskan analisis credit utilization dan kombinasi DSR × utilization untuk Gold marts utama. Ini merupakan keputusan berbasis hasil eksplorasi, bukan berarti faktor pekerjaan atau pendapatan tidak relevan dalam konteks risiko secara umum.

---

## 12. Data Quality Results dan Validasi Output

### 12.1 Validasi staging

Setelah staging dibuat, pemeriksaan BigQuery menunjukkan:

- row count: 10.000;
- distinct `borrower_id`: 10.000;
- duplicate `borrower_id`: 0.

### 12.2 Validasi Gold marts

| Model | Pemeriksaan tambahan | Hasil |
|---|---|---|
| `mart_twp90_monitoring` | Lima kategori status; jumlah borrower per kategori sesuai staging; total share 100%. | Sesuai |
| `mart_borrower_segmentation` | Empat segmen; total borrower 10.000; persentase lima status per segmen mendekati 100%. | Sesuai |
| `mart_credit_risk` | 16 kombinasi; total borrower 10.000; total default 2.538; overall default rate 25,38%. | Sesuai |

### 12.3 Rekapitulasi dbt tests

| Model / layer | PASS | WARN | ERROR |
|---|---:|---:|---:|
| Staging | 7 | 0 | 0 |
| `mart_twp90_monitoring` | 6 | 0 | 0 |
| `mart_borrower_segmentation` | 7 | 0 | 0 |
| `mart_credit_risk` | 8 | 0 | 0 |
| **Total** | **28** | **0** | **0** |

Test menguji aturan yang didefinisikan proyek. Kelulusan test bukan bukti bahwa seluruh data benar secara faktual atau merepresentasikan populasi industri; test hanya menunjukkan bahwa data memenuhi kontrak dan aturan yang telah ditulis.

---

## 13. dbt Lineage dan Dokumentasi

Dependency utama yang dihasilkan dbt:

```text
source: fintech_raw.borrower_data
                 |
                 v
       stg_borrowers (Silver)
          /       |       \
         v        v        v
      mart_     mart_     mart_
      twp90_    borrower_ credit_
      monitoring segmentation risk
```

Model-model Gold mereferensikan staging melalui `ref()`, sementara staging mengacu pada raw melalui `source()`. Dependency ini memungkinkan dbt menyusun lineage graph dan menentukan urutan eksekusi.

Perintah dokumentasi:

```bash
dbt docs generate
dbt docs serve
```

`dbt docs generate` berhasil menghasilkan metadata katalog. Saat proses tersebut terdapat warning metadata `table_owner` yang tidak cocok dengan kolom tabel; warning ini tidak menggagalkan pembuatan dokumentasi maupun eksekusi model dan tests.

---

## 14. Menjalankan Project

### 14.1 Prasyarat

- Python 3.11 atau versi kompatibel.
- Google Cloud project dengan akses BigQuery.
- Google Cloud SDK.
- dbt Core dan adapter BigQuery yang kompatibel.
- Git.

### 14.2 Instalasi environment Python

Contoh perintah pada Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install pandas pyarrow db-dtypes google-cloud-bigquery dbt-core dbt-bigquery
```

Jika PowerShell memblokir aktivasi environment pada sesi tersebut, kebijakan dapat diubah sementara untuk proses terminal saat itu sesuai kebijakan perangkat:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

### 14.3 Clone repository

```bash
git clone https://github.com/Iwannnwn/AnalyticsEngineering-Project.git
cd AnalyticsEngineering-Project
```

### 14.4 Konfigurasi Google Cloud

Autentikasi dan pilih project sesuai akses akun:

```bash
gcloud init
gcloud auth application-default login
gcloud config set project fintech-analytics-engineering
```

Buat dataset BigQuery berikut pada lokasi `asia-southeast2` jika belum tersedia:

- `fintech_raw`
- `fintech_staging` akan digunakan oleh dbt.
- `fintech_marts` akan digunakan oleh dbt.

Raw table dibuat melalui script ingestion. Dataset staging dan marts perlu tersedia atau dibuat oleh proses yang memiliki izin membuat dataset.

### 14.5 Konfigurasi dbt profile

File profile lokal: `~/.dbt/profiles.yml` (Windows: `%USERPROFILE%\.dbt\profiles.yml`).

```yaml
fintech_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: fintech-analytics-engineering
      dataset: fintech_staging
      threads: 4
      location: asia-southeast2
      job_execution_timeout_seconds: 300
```

Jangan commit file profile atau file credential lokal ke GitHub. Pastikan `profile:` pada `dbt_project.yml` bernilai `fintech_analytics`.

### 14.6 Menyiapkan data sumber

Letakkan file CSV pada lokasi lokal:

```text
data/raw/fintech_dataset.csv
```

Jalankan profiling dan validasi:

```powershell
python scripts/profile_data.py
python scripts/validate_data.py
```

Kemudian muat data ke BigQuery:

```powershell
python scripts/ingest_to_bigquery.py
```

**Catatan dataset:** file raw tidak disimpan di repository karena berada di bawah aturan `.gitignore`. Pengguna repository perlu memperoleh dataset dari sumber yang sah dan meletakkannya pada path tersebut.

### 14.7 Menjalankan dbt

Dari direktori `fintech_analytics`:

```bash
dbt debug
dbt parse
dbt run
dbt test
```

Baris terakhir sebaiknya dijalankan sebagai `dbt test` tanpa spasi awal. Untuk eksekusi bertahap atau selektif:

```bash
dbt run --select stg_borrowers
dbt test --select stg_borrowers

dbt run --select mart_twp90_monitoring
dbt test --select mart_twp90_monitoring

dbt run --select mart_borrower_segmentation
dbt test --select mart_borrower_segmentation

dbt run --select mart_credit_risk
dbt test --select mart_credit_risk
```

Untuk melihat preview model:

```bash
dbt show --select stg_borrowers --limit 5
```

Untuk membangun ulang model dan menjalankan test terkait dalam satu command, `dbt build` juga dapat dipertimbangkan setelah dependency dan konfigurasi diverifikasi.

---

## 15. Repository Structure

Struktur utama proyek:

```text
AnalyticsEngineering-Project/
├── data/
│   ├── raw/                         # Dataset lokal; diabaikan Git
│   └── processed/
├── scripts/
│   ├── profile_data.py              # Profiling dataset
│   ├── validate_data.py             # Validasi awal dataset
│   └── ingest_to_bigquery.py        # Ingestion ke BigQuery
├── sql/                             # Query analisis eksploratif
├── docs/
│   └── PROJECT_DOCUMENTATION.md     # Dokumentasi teknis proyek
├── fintech_analytics/
│   ├── models/
│   │   ├── staging/
│   │   │   ├── sources.yml
│   │   │   ├── stg_borrowers.sql
│   │   │   └── schema.yml
│   │   └── marts/
│   │       ├── mart_twp90_monitoring.sql
│   │       ├── mart_borrower_segmentation.sql
│   │       ├── mart_credit_risk.sql
│   │       └── schema.yml
│   ├── tests/
│   │   ├── assert_borrower_dpd_status_consistency.sql
│   │   ├── assert_non_negative_financial_values.sql
│   │   ├── assert_financial_ratios_consistency.sql
│   │   ├── assert_twp90_monitoring_aggregation.sql
│   │   ├── assert_borrower_segmentation_distribution.sql
│   │   └── assert_credit_risk_unique_segments.sql
│   ├── macros/
│   │   └── generate_schema_name.sql
│   └── dbt_project.yml
├── .gitignore
└── README.md
```

File dan folder generated seperti `.venv/`, `logs/`, `target/`, `dbt_packages/`, serta data mentah lokal sebaiknya tidak dimasukkan ke version control. Konfigurasi autentikasi harus tetap berada di luar repository.

---

## 16. Engineering Decisions

| Keputusan | Alasan |
|---|---|
| Menggunakan Medallion Architecture | Memisahkan source raw, standardisasi, dan kebutuhan analitik. |
| Raw table tetap dipertahankan | Menjaga source of truth dan memungkinkan transformasi diulang. |
| Explicit column selection pada staging | Mengendalikan schema dan mencegah perubahan sumber menyebar tanpa review. |
| Staging materialized sebagai view | Menghindari penyimpanan salinan staging yang tidak dibutuhkan pada skala proyek ini. |
| Marts materialized sebagai table | Menyediakan hasil agregasi siap pakai untuk penggunaan berulang. |
| `SAFE_DIVIDE()` untuk rasio | Mencegah error pembagian dengan nol pada query BigQuery. |
| Tidak memangkas rasio di atas 1 secara otomatis | Nilai tersebut dapat memiliki makna risiko dan perlu investigasi, bukan koreksi otomatis. |
| Cut-off segmentasi eksploratif | Memberi kategori yang mudah dibaca; ambang bukan standar regulasi. |
| dbt generic dan singular tests | Menggabungkan pemeriksaan schema-level dengan aturan bisnis lintas kolom dan agregasi. |
| `WRITE_TRUNCATE` pada ingestion | Memudahkan reproducibility full refresh untuk dataset statis proyek ini. |

---

## 17. Limitations dan Next Improvements

### 17.1 Keterbatasan saat ini

1. **Snapshot, bukan time series.** Dataset tidak memiliki tanggal observasi historis untuk mengukur roll rate, vintage, cohort, atau perubahan DPD dari waktu ke waktu.
2. **Representativeness belum terbukti.** Ukuran 10.000 baris tidak dengan sendirinya membuktikan bahwa data mewakili populasi borrower fintech Indonesia.
3. **Definisi variabel belum seluruhnya terdokumentasi.** Formula distress index, disposable income, confidence score, dan sebagian label perlu dikonfirmasi dari pemilik dataset.
4. **Potensi circularity.** Rasio, distress index, dan status default mungkin memiliki keterkaitan formula atau aturan pembentukan. Hal ini harus diperiksa sebelum membangun model prediksi.
5. **Cut-off segmentasi bersifat eksploratif.** Threshold perlu divalidasi dengan business owner dan data historis sebelum diterapkan pada keputusan kredit.
6. **Ingestion full refresh.** Pipeline belum incremental, belum memiliki watermark, dan belum dirancang untuk penanganan data terlambat atau perubahan record.
7. **Belum ada orchestration.** Eksekusi saat ini dilakukan melalui command line; belum dijadwalkan oleh Airflow, Cloud Composer, atau layanan orchestration lain.
8. **Belum ada environment deployment terpisah.** Konfigurasi pengembangan, staging deployment, dan production deployment belum dipisah secara formal.

### 17.2 Pengembangan lanjutan

- Menambahkan metadata waktu dan historical snapshot untuk analisis tren serta roll-rate.
- Menerapkan incremental loading dan strategi deduplication/upsert sesuai grain sumber.
- Mengembangkan source freshness dan test untuk validitas denominator, nullability, accepted range, serta referential integrity jika tabel terkait ditambahkan.
- Menyimpan definisi metric dan threshold dalam YAML/seed agar perubahan lebih mudah ditinjau.
- Menguji dampak perubahan threshold dengan sensitivity analysis.
- Menambahkan dashboard untuk TWP90 distribution, utilization segment, dan DSR × utilization risk matrix.
- Menambahkan CI pipeline untuk `dbt parse`, `dbt compile`, dan `dbt test` pada pull request.
- Memisahkan credential, dataset, dan target dbt untuk development dan production.
- Memvalidasi seluruh definisi domain bersama sumber data atau pemilik proses sebelum penggunaan keputusan bisnis.

---

## 18. Final Project Summary

Proyek ini membangun alur **Fintech Lending Analytics Engineering** dari file CSV hingga data warehouse analitik di BigQuery. Python dan pandas digunakan untuk profiling, validasi awal, serta ingestion. dbt mengelola transformasi SQL melalui Medallion Architecture: Bronze untuk raw source, Silver untuk staging model dan data quality checks, serta Gold untuk tiga data marts.

Tiga Gold marts menyediakan:

1. **TWP90 monitoring:** ringkasan lima status pembayaran dan outstanding. Kategori `Default-Macet-TWP90` mencakup 2.538 borrower atau 25,38% dari dataset.
2. **Borrower segmentation:** default rate pada kelompok Very High Utilization mencapai 78,54% dalam dataset.
3. **Credit risk matrix:** kombinasi Very High DSR dan Very High Utilization memiliki default rate 92,64% (1.309 dari 1.413 borrower).

Kualitas transformasi diperiksa dengan **28 dbt tests**, yang seluruhnya PASS pada eksekusi proyek. Test tersebut mencakup uniqueness, not-null, accepted values, konsistensi DPD terhadap status, nilai finansial non-negatif, validasi formula rasio, rekonsiliasi agregasi, distribusi persentase, dan keunikan kombinasi segmen.

Hasil memberikan contoh bagaimana data mentah dapat diubah menjadi aset analitik yang terstruktur dan dapat diuji. Temuan risiko harus tetap dipahami sebagai pola pada dataset yang digunakan, bukan bukti kausal atau gambaran pasti seluruh industri fintech Indonesia.

---

## 19. Quick Reference: Commands

```bash
# Validate dbt connection and project
dbt debug
dbt parse

# Run all models and tests
dbt run
dbt test

# Run a specific model and its tests
dbt run --select mart_credit_risk
dbt test --select mart_credit_risk

# Inspect a model
dbt show --select stg_borrowers --limit 5

# Generate and serve dbt documentation
dbt docs generate
dbt docs serve
```

---

**End of documentation.**
