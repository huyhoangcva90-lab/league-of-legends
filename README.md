# LoL Analyst — Hướng dẫn sử dụng

LoL Analyst là công cụ phân tích draft, đội hình, matchup và kế hoạch thi đấu League of Legends. Ứng dụng chạy trực tiếp trong trình duyệt, không cần Google Sheets và không cần backend.

## 1. Mở đúng ứng dụng

### Ứng dụng chính

Mở file:

```text
index.html
```

Đây là phiên bản sử dụng dữ liệu và logic chính, gồm Team Analyzer, Draft, Champion Finder, Matchups, Teamfight, Compare, Map, Strategy và thư viện dữ liệu.

### Ứng dụng tham khảo trong thư mục `lol`

Mở file:

```text
lol/index.html
```

Phiên bản này mô phỏng trực tiếp cấu trúc workbook và được dùng làm nguồn tham khảo thiết kế cho màn Team. Hai ứng dụng lưu trạng thái độc lập trong trình duyệt.

## 2. Quy trình sử dụng nhanh

1. Mở **Team Analyzer** hoặc **Draft Room**.
2. Chọn đủ năm tướng cho Blue Team và Red Team.
3. Mỗi vị trí tương ứng với Top, Jungle, Mid, AD và Support.
4. Chọn hoặc thay tướng bằng cách nhấn vào hàng champion.
5. Hover hoặc focus bằng bàn phím vào champion để xem thông tin chi tiết.
6. Cuộn xuống để đọc toàn bộ phân tích đội hình.
7. Dùng **Swap sides / Đổi bên** nếu muốn đảo góc nhìn Blue và Red.

Trạng thái đội hình được tự động lưu trong `localStorage`. Khi mở lại trình duyệt, đội hình gần nhất sẽ được khôi phục.

## 3. Màn Team Analyzer

Màn Team sử dụng bố cục đối xứng Blue/Red theo thiết kế trong `lol/sheet-app.js` và `lol/sheet-app.css`.

### 3.1. Hàng champion

Mỗi champion hiển thị:

- Vị trí thi đấu.
- Portrait và tên champion.
- Physical, Magic hoặc Hybrid damage.
- Damage profile.
- Early, Mid và Late power.
- Class và subclass.
- Combat type: Engage, Disengage, Poke, Catch hoặc Split.
- Formation: Frontline, Midline, Backline hoặc Flank.
- Icon Passive, Q, W, E và R.

Nhấn vào hàng champion để đổi lựa chọn. Champion đã được chọn ở vị trí khác sẽ không thể chọn trùng.

### 3.2. Ban projection và tỷ lệ đội

Khối projection hiển thị:

- Champion nên ưu tiên ban cho mỗi đội.
- Lane liên quan đến đề xuất ban.
- Tỷ lệ Blue/Red dựa trên trung bình năm lane.

Tỷ lệ này là **inferred pressure**, không phải win rate live. Nó được tính từ power đầu trận, damage, control, mobility, range và quan hệ matchup hiện có.

### 3.3. Power curve

Power curve được phân tích riêng theo từng cặp lane và ba giai đoạn:

- **Early:** sức mạnh đầu trận và khả năng tạo quyền ưu tiên.
- **Mid:** sức mạnh khi bắt đầu group và tranh mục tiêu.
- **Late:** scaling và khả năng vận hành giao tranh cuối trận.

`Weighted output` là điểm tổng hợp của năm champion. Không nên chỉ nhìn điểm tổng; hãy kiểm tra từng lane để tránh che mất một matchup thua nặng.

### 3.4. Combat identity

Năm hệ vận hành chính:

- **Engage:** chủ động mở giao tranh.
- **Disengage:** ngắt hoặc thoát giao tranh.
- **Poke:** cấu máu từ xa trước mục tiêu.
- **Catch:** bắt mục tiêu sai vị trí.
- **Split:** tạo áp lực ở đường cánh.

Portrait contributor cho biết champion nào trực tiếp đóng góp vào từng hệ.

### 3.5. Formation và damage profile

Formation cho biết số champion phù hợp với:

- Frontline.
- Midline.
- Backline.
- Flank.

Damage profile so sánh:

- Burst và DPS.
- Melee và Ranged.
- Physical và Magic.
- Basic attack và Ability dependency.

### 3.6. Chỉ số tổng hợp

Các chỉ số được tính từ trung bình champion đang chọn:

- Damage.
- Toughness.
- Control.
- Mobility.
- Utility.
- Clearwave.
- Tower pressure.

Điểm hiển thị là giá trị phân tích nội bộ, không phải chỉ số trực tiếp trong client League of Legends.

### 3.7. Trigger matrix

Trigger matrix chỉ hiển thị champion đạt điều kiện:

- Dive hoặc Dash.
- Clearwave từ 70 trở lên.
- Clearwave từ 65 trở lên.
- Tower pressure từ 65 trở lên.
- Strong Ultimate hoặc Teamfight Ultimate.

### 3.8. Skill comparison

Mỗi lane có bảng đối xứng hai champion với:

- Passive, Q, W, E và R.
- Ảnh và tên kỹ năng.
- Cooldown nếu dữ liệu có sẵn.
- Skill tags.
- Strong Ultimate hoặc Teamfight tag.

### 3.9. Matchup từng lane

Mỗi cặp Top, Jungle, Mid, AD và Support hiển thị:

- Hai champion.
- Lane pressure.
- Kỹ năng quan trọng.
- Early power và damage profile.
- Matchup relation theo đúng lane.
- Game plan và power spike.

Nếu có nguồn ngoài, công cụ mở đúng trang matchup theo role. Dữ liệu live và dữ liệu inferred luôn được tách riêng.

### 3.10. Teamfight, warnings và gợi ý thay tướng

Phần cuối trang gồm:

- Teamfight ranking từ 1 đến 5.
- Split pusher và flank threat.
- Hard CC, Dive, Wave clear và Tower pressure.
- Strong Ultimate.
- Cảnh báo `info`, `warning` hoặc `critical`.
- Nguyên nhân cảnh báo.
- Cách sửa đội hình.
- Champion gợi ý thay thế.
- Kết luận lợi thế theo từng trục.

## 4. Draft Room

Draft Room hỗ trợ trình tự ban/pick chuyên nghiệp 20 lượt.

- Pick không bị khóa role ngay khi draft.
- Có thể gán role sau khi hoàn thành.
- Hỗ trợ BO3 và BO5.
- Fearless Draft khóa champion đã được chọn ở game trước.
- Có pool tướng của đội mình và đối thủ.
- Có gợi ý Best Fit, Best Ban, Counter, Best Lane và Matchup.

Sau khi draft xong, mở Team Analyzer để đọc đội hình đầy đủ.

## 5. Champion Finder và Check

Finder dùng quy tắc:

- **OR** giữa các giá trị trong cùng một nhóm.
- **AND** giữa các nhóm khác nhau.
- Required capabilities phải khớp đầy đủ.

Có thể lọc theo role, class, combat type, range, power curve, damage, tier, release year và capability.

## 6. Matchups và Compare

### Matchups

Hiển thị theo lane:

- Counter hoặc threat.
- Favorable lane.
- Synergy hoặc best duo.
- Priority ban.
- Liên kết nguồn matchup.

### Compare

So sánh hai champion về:

- Base stats và chỉ số theo level.
- Role, class, damage và combat type.
- Passive/Q/W/E/R.
- Strengths và weaknesses.
- Game plan và power spike.
- Lane-specific matchup.

## 7. Teamfight, Map và Strategy

### Teamfight

- Formation và combat roles.
- Engage chain và follow-up.
- Priority target.
- Front-to-back hoặc flank.
- Combat radar và scenario score.
- Objective affinity.

### Map

- Jungle route của hai đội.
- Lane priority.
- Objective plan.
- Các bước clear và gank.

### Strategy

- Early, Mid và Late plan.
- Macro style.
- Win condition.
- Rủi ro đội hình.
- Objective execution.

## 8. Phân biệt dữ liệu observed và inferred

- **Observed/imported:** dữ liệu nhập từ workbook, Riot Data Dragon hoặc nguồn matchup.
- **Derived/inferred:** kết quả tính từ tag, rating và quy tắc nội bộ.
- **Missing:** dữ liệu chưa tồn tại; công cụ không tự bịa giá trị live.

Win rate, gold difference hoặc matchup live chỉ được hiển thị khi có dữ liệu hoặc liên kết nguồn rõ ràng.

## 9. Cập nhật dữ liệu

### Kiểm tra dữ liệu hiện tại

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-data.ps1
```

Kiểm tra thêm việc các file runtime đã build còn đồng bộ với JSON nguồn:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-data.ps1 -CheckGenerated
```

### Regenerate dữ liệu trình duyệt

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-data.ps1
```

### Cập nhật Riot Data Dragon

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-riot-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-data.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-team-data.ps1
```

`update-riot-data.ps1` tự lấy patch Data Dragon mới nhất, cập nhật ảnh/kỹ năng/hồi chiêu, giữ các form riêng của workbook và tạo hồ sơ baseline có đánh dấu rà soát khi Riot bổ sung tướng mới. Có thể truyền `-Patch 16.14.1` để build tái lập theo một phiên bản cố định.

Không chỉnh trực tiếp `data.js` nếu thay đổi cần được giữ lâu dài. Hãy sửa dữ liệu nguồn trong `src/data`, sau đó chạy `build-data.ps1`.

## 10. Cấu trúc file quan trọng

```text
index.html                  App chính
app.js                      State, phân tích và renderer
style.css                   Giao diện app chính
data.js                     Dữ liệu runtime đã build
matchup-lanes.js            Matchup theo lane
sheet-details.js            Dữ liệu Champion/Skill từ workbook
jungle-details.js           Chi tiết jungle route
src/data/                   Dữ liệu nguồn
scripts/                    Script validate/build/update
lol/                        App workbook tham khảo
```

## 11. Xử lý lỗi thường gặp

### Trang trắng

1. Mở Developer Tools và xem tab Console.
2. Kiểm tra `index.html` có load đủ file JavaScript không.
3. Chạy validation dữ liệu.
4. Kiểm tra cú pháp file vừa chỉnh.
5. Hard reload bằng `Ctrl + F5`.

### Không thấy thay đổi mới

- Hard reload trình duyệt.
- Đảm bảo đang mở đúng `index.html`.
- App chính và `lol/index.html` là hai ứng dụng khác nhau.

### Đội hình cũ vẫn xuất hiện

Dùng nút **Đặt lại workspace** hoặc xóa Local Storage của trang.

### Ảnh champion không hiện

Kiểm tra kết nối mạng và đường dẫn Data Dragon. Nội dung phân tích vẫn hoạt động nếu ảnh ngoài không tải được.

## 12. Nguyên tắc khi chỉnh sửa

- Chỉ thay UI màn Team khi yêu cầu liên quan đến thiết kế Team.
- Không thay renderer hoặc logic của các màn khác nếu không được yêu cầu.
- Thư mục `lol` là nguồn tham khảo, không tự động thay thế app chính.
- Logic phân tích phải tách khỏi HTML/CSS.
- Không trộn dữ liệu live với điểm inferred.
- Mọi thay đổi dữ liệu phải chạy validation trước khi bàn giao.
