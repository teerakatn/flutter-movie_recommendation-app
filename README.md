โครงการ

ข้อกำหนดเบื้องต้น:
- มี API Key ของ TMDb (จำเป็น) และ OMDb (ไม่จำเป็น แต่แนะนำ)

ตั้งค่า API Key:
- TMDb: เปิดไฟล์ `lib/main.dart` และแก้ค่าตัวแปร `apiKey` ในคลาส `MovieListPage` ให้เป็น TMDb API Key ของคุณ
- OMDb: โค้ดมีคีย์เเท้
รันโครงการ (แนะนำรันบนเว็บพอร์ต 3000):
flutter run -d chrome --web-port=3000

## ใช้ API อะไรบ้าง

แอปนี้ใช้ข้อมูลจากบริการต่อไปนี้:

- The Movie Database (TMDb)
	- ใช้ดึงรายการและรายละเอียดของภาพยนตร์ รวมถึงวิดีโอตัวอย่าง ผู้ให้บริการสตรีมมิ่ง และลิงก์ IMDb
	- Endpoints ที่ใช้งาน (ตัวอย่าง):
		- `GET /movie/popular`
		- `GET /movie/top_rated`
		- `GET /movie/upcoming`
		- `GET /search/movie`
		- `GET /movie/{id}` (ใช้คะแนนโหวต TMDb เป็น fallback)
		- `GET /movie/{id}/videos`
		- `GET /movie/{id}/watch/providers`
		- `GET /movie/{id}/recommendations`
		- `GET /movie/{id}/external_ids` (เพื่อหา `imdb_id`)

- OMDb API
	- ใช้ดึงคะแนนจากแหล่งภายนอก เช่น IMDb / Rotten Tomatoes / Metacritic
	- รูปแบบการเรียกที่ใช้: `GET https://www.omdbapi.com/?i={imdbId}&apikey={key}`


## อธิบายฟังก์ชันหลัก (Function-by-Function)

อธิบายเฉพาะฟังก์ชัน/คลาสที่สำคัญต่อการทำงานของแอป โดยจัดตามไฟล์

### lib/main.dart

- `main()`
	- เริ่มต้น Flutter bindings และเรียก `runApp(MyApp())`

- `class MyApp extends StatelessWidget`
	- กำหนดธีม Material 3, ฟอนต์, และตั้ง `home` เป็น `MovieListPage`

- `class Movie`
	- โมเดลข้อมูลภาพยนตร์ที่ใช้ทั่วทั้งแอป
	- `factory Movie.fromJson(Map<String, dynamic> json)` แปลง JSON จาก TMDb เป็นอ็อบเจกต์ `Movie`

- `class MovieListPage extends StatefulWidget`
	- หน้าหลักของแอป มีโหมด Home และโหมด Search

- `_fetchCategory(String path, {int target = 20, int maxPages = 3}) -> Future<List<Movie>>`
	- ตัวดึงข้อมูลแบบ generic สำหรับรายการหมวดหมู่ TMDb (popular/top_rated/upcoming) พร้อมการ paginate หลายหน้าและกรอง adult ออก

- `fetchMovies() -> Future<List<Movie>>`
	- เพื่อความเข้ากันได้ย้อนหลัง ใช้เรียก popular เป็นค่าเริ่มต้น (ใช้ในโหมดค้นหาเดิม)

- `searchMovies(String query) -> Future<List<Movie>>`
	- เรียก TMDb `/search/movie` โดยกรอง adult ออก

- `_performSearch()` / `_clearSearch()`
	- ควบคุม state ของโหมดค้นหาและค่าใน `TextEditingController`

- `_buildSearchBody(BuildContext)`
	- UI โหมดค้นหา: ช่องค้นหา + Grid ผลลัพธ์แบบ responsive

- `_buildHomeBody(BuildContext)`
	- UI โหมดหน้าแรก: Hero Banner + 3 แถวแนวนอน (Popular, Top Rated, Upcoming) พร้อมดึงข้อมูลใหม่ได้ด้วย pull-to-refresh

### lib/moviedetailpage.dart

- `class ExternalRatings`
	- โครงสร้างข้อมูลสำหรับคะแนนภายนอก (IMDb / Rotten Tomatoes / Metacritic) และ TMDb เป็น fallback

- `class MovieDetailPage`
	- หน้ารายละเอียดภาพยนตร์ แสดง Header แบบ Backdrop + ปุ่ม Play Trailer / My List, คำอธิบาย, คะแนนภายนอก, ผู้ให้บริการ, และ “More like this”

- `fetchProviders(int movieId) -> Future<List<String>>`
	- TMDb: `/movie/{id}/watch/providers` เลือกเฉพาะ US/flatrate และคืนชื่อผู้ให้บริการ

- `fetchRecommendations(int movieId) -> Future<List<Movie>>`
	- TMDb: `/movie/{id}/recommendations` แปลงเป็นลิสต์ `Movie`

- `fetchTrailer(int movieId) -> Future<Uri?>`
	- TMDb: `/movie/{id}/videos` เลือก YouTube/Vimeo ประเภท Trailer/Teaser สร้าง URL ดูได้ทันที

- `_openTrailer(Uri uri) -> Future<void>`
	- เปิดลิงก์ตัวอย่างด้วย `url_launcher` (โหมดแอปภายนอก)

- `_fetchImdbId(int movieId) -> Future<String?>`
	- TMDb: `/movie/{id}/external_ids` เพื่อหา `imdb_id`

- `fetchExternalRatings(int movieId) -> Future<ExternalRatings?>`
	- ดึงคะแนนหลายแหล่ง:
		1) หากรันบน Web จะ “จำลอง” คะแนนจาก TMDb เพื่อแสดงหลายแหล่งอย่างสมจริง (หลีกเลี่ยง CORS)
		2) หากมี `imdb_id` จะลองเรียก OMDb ด้วยหลายคีย์แบบ fallback และสำรองด้วยการค้นหาด้วยชื่อ/ปี
		3) หากทั้งหมดล้มเหลว จะ fallback เป็นคะแนนจาก TMDb (`_fetchTmdbVoteRating`)

- `_fetchTmdbVoteRating(int movieId) -> Future<ExternalRatings?>`
	- TMDb: `/movie/{id}` เพื่ออ่าน `vote_average`/`vote_count` แล้วสร้าง `ExternalRatings` แบบ TMDb

### lib/widgets/hero_banner.dart

- `class HeroBanner`
	- แบนเนอร์สไลด์แบบ 16:9 ปรับความสูงแบบ responsive มีพื้นหลังไล่เฉด ปุ่ม Play/More info และเรียก `onTap` เมื่อกด

- `class HeroBannerItem`
	- ข้อมูลรายการในแบนเนอร์: id, title, overview, backdropUrl, tagline

### lib/widgets/movie_row.dart

- `class SectionHeader`
	- หัวข้อแถว มีปุ่ม “See all” (ตัวเลือก)

- `class MovieRow`
	- แถวภาพยนตร์เลื่อนแนวนอน มีปุ่มลูกศรซ้าย/ขวาซ้อนทับและเอฟเฟกต์ไล่เฉดด้านข้าง คำนวณระยะเลื่อนแบบ “เกือบหนึ่งหน้า” ให้ใช้งานง่าย

- `class MovieCardData` / `class MovieCard`
	- โครงสร้างข้อมูลและการ์ดโปสเตอร์แต่ละรายการ ใช้ `CachedNetworkImage` พร้อม Shimmer เป็น skeleton ระหว่างโหลด

---

