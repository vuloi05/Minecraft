# LỘ TRÌNH VIBE CODING MINECRAFT CÙNG AI (SOLO DEV) — v2

**Mục tiêu dự án**: Tự kiểm chứng xem một người + AI có thể build lại được (bản rút gọn của) một hệ thống game lâu đời như Minecraft hay không. Không thương mại hóa. Không multiplayer, không mod. Chỉ cần cảm giác **Minecraft Singleplayer thuần túy** — kể cả sinh tồn cơ bản, không chỉ là "đặt/xóa khối".

---

## 🛠️ PHẦN 1: CÔNG NGHỆ & QUY TẮC LÀM VIỆC

- **Engine**: Godot (GDScript hoặc C#) — toàn bộ scene/code dạng text, AI đọc/sửa được trọn vẹn, không có "góc khuất" như Unity Inspector.
- **Repo gốc**: Tìm 1 template Godot Voxel cơ bản trên GitHub làm điểm xuất phát, thay vì gõ chay từ số 0.
- **Nguyên tắc Micro-task**: Mỗi gạch đầu dòng phải đủ nhỏ để AI code xong trong 1 lần trả lời. Nếu thấy task nào to, chẻ nhỏ hơn nữa khi thực thi.
- **Playtest bắt buộc**: Mỗi task xong → bật game test ngay theo đúng "Tiêu chí nghiệm thu". Không đạt thì không merge sang task tiếp theo.
- **Git commit liên tục**: 1 task nhỏ pass test → commit ngay. Message rõ ràng (vd: `feat: raycast xoa/dat block`).
- **Cấm Đa luồng (Multi-threading)** cho tới khi có lý do rõ ràng (FPS đo được là quá thấp) — race condition rất khó gỡ qua chat với AI.
- **Không né bản quyền**: vì không thương mại hóa, có thể làm giống Minecraft hết mức (tên block, cơ chế, cảm giác chơi).

---

## 📋 PHẦN 2: LỘ TRÌNH

### 🔵 Giai đoạn 1: "Hello Voxel" — Cốt lõi tương tác
| # | Task | Tiêu chí nghiệm thu |
|---|------|----------------------|
| 1.1 | Khởi tạo Project Godot, scene 3D rỗng | Mở game ra thấy nền trời, không lỗi console |
| 1.2 | Thêm `CharacterBody3D` làm người chơi + script di chuyển WASD | Đi 4 hướng, không xuyên sàn |
| 1.3 | Thêm trọng lực + nhảy (Space) | Nhảy lên rơi xuống mượt, không kẹt |
| 1.4 | Thêm 1 khối `MeshInstance3D` + `CollisionShape3D` giữa map | Đứng cạnh khối không xuyên qua được |
| 1.5 | `RayCast3D` từ camera: left-click xóa khối | Click trúng khối, khối biến mất |
| 1.6 | Right-click: đặt khối mới tại mặt vừa nhìn trúng | Đặt được khối liền kề đúng hướng nhìn, không đè lên khối cũ |

*Commit sau mỗi task. Test cuối giai đoạn: đi vòng quanh, nhảy lên khối, đập/đặt lại 10 lần không lỗi.*

---

### 🟢 Giai đoạn 2: Quản lý Dữ liệu & Lưới (The Grid)
| # | Task | Tiêu chí nghiệm thu |
|---|------|----------------------|
| 2.1 | Khai báo mảng 3D `int[x][y][z]` kích thước 16x16x16, giá trị mặc định 1 (đá) | In ra console kích thước mảng đúng |
| 2.2 | Viết vòng lặp duyệt mảng, mỗi ô có giá trị 1 thì spawn 1 khối tại đúng tọa độ | Thấy khối xếp thành khối lập phương 16x16x16 đặc |
| 2.3 | Chuyển hệ render sang `SurfaceTool` (gộp mesh) thay vì spawn từng node riêng | FPS không tụt khi có 4096 khối, chỉ 1 draw call |
| 2.4 | Raycast: tính tọa độ thế giới → tọa độ chỉ số mảng (grid index) | Console in đúng tọa độ mảng khi click vào 1 khối bất kỳ |
| 2.5 | Click xóa/đặt: sửa giá trị trong mảng (không sửa mesh trực tiếp) → gọi lại hàm dựng mesh | Xóa/đặt vẫn hoạt động đúng, dữ liệu mảng phản ánh đúng trạng thái |

*Test cuối giai đoạn: xóa 1 lớp đáy, thế giới không sập; đặt lại full khối, không lỗi hình.*

---

### 🟡 Giai đoạn 3: Sinh Địa Hình & Tối Ưu (không đa luồng)
| # | Task | Tiêu chí nghiệm thu |
|---|------|----------------------|
| 3.1 | Tích hợp `FastNoiseLite`, in độ cao noise ra console theo x,z | Giá trị noise thay đổi mượt khi x,z thay đổi |
| 3.2 | Dùng độ cao noise để quyết định block nào là đá/đất/cỏ theo trục Y | Nhìn thấy đồi núi nhấp nhô, có lớp cỏ trên cùng |
| 3.3 | **Culling mặt khuất**: chỉ vẽ mặt khối tiếp giáp không khí | FPS tăng rõ rệt (đo bằng Godot profiler), không còn thấy khối "chui" qua tường khi bay vào trong |
| 3.4 | Chia bản đồ thành các Chunk 16x16 (nhiều mảng 3D con thay vì 1 mảng khổng lồ) | Sinh được ít nhất 3x3 chunk liền kề không có khoảng hở giữa các chunk |
| 3.5 | Ẩn/hiện chunk theo khoảng cách người chơi (show/hide node, chưa cần load/unload động) | Đi xa chunk tự ẩn, quay lại tự hiện, không giật hình |

*Test cuối giai đoạn: chạy vòng quanh bản đồ 9 chunk, FPS ổn định, không lỗi hở khối giữa các chunk.*

---

### 🟠 Giai đoạn 4: Vòng Lặp Sinh Tồn Tối Giản (linh hồn của Minecraft)
> Đây là phần khiến game "giống Minecraft" thật sự, không chỉ là voxel editor.

| # | Task | Tiêu chí nghiệm thu |
|---|------|----------------------|
| 4.1 | Hệ thống Máu (Health, 0-20), UI thanh tim đơn giản góc màn hình | Máu hiện đúng số, giảm khi rơi từ cao |
| 4.2 | Hệ thống Đói (Hunger, 0-20), giảm dần theo thời gian thực | Sau vài phút không ăn, số đói giảm về 0, máu bắt đầu giảm theo |
| 4.3 | Chu kỳ Ngày/Đêm: xoay `DirectionalLight3D` theo bộ đếm thời gian | 1 chu kỳ ngày/đêm rõ ràng lặp lại (vd 10-20 phút thực) |
| 4.4 | Tool tiers tối giản: tay không đào chậm, thêm 1 loại "cuốc" đào đá nhanh hơn | Đào đá bằng tay mất ~3s, bằng cuốc ~1s (đặt thời gian tùy chỉnh) |
| 4.5 | Inventory + Hotbar (9 ô), nhặt block vào đúng ô, hiện số lượng | Đào khối → xuất hiện đúng trong hotbar, số lượng cộng dồn |
| 4.6 | Crafting tối giản: UI 2x2, công thức gỗ→ván, ván→cuốc (que + ván) | Ghép đúng công thức ra đúng item, sai công thức không ra gì |
| 4.7 | 1 loại Mob: Zombie đơn giản (spawn ban đêm, đi thẳng về phía người chơi trong tầm nhìn X mét, gây damage khi chạm) | Ban đêm zombie xuất hiện, đuổi theo, chạm vào bị trừ máu; ban ngày không spawn |
| 4.8 | Ánh sáng đuốc lan tỏa (Torch item + light propagation qua BFS đơn giản, không cần đa luồng vì world nhỏ) | Đặt đuốc trong hang tối, vùng sáng lan ra mềm mại vài ô xung quanh |

*Test cuối giai đoạn: sống sót qua 1 đêm có zombie tấn công, đào đủ nguyên liệu chế được cuốc, đói/máu vận hành đúng logic.*

---

### 🔴 Giai đoạn 5: Đóng Gói v1.0
| # | Task | Tiêu chí nghiệm thu |
|---|------|----------------------|
| 5.1 | Save/Load: xuất mảng chunk + vị trí người chơi + máu/đói ra file `world.json` | Tắt game, mở lại, mọi thứ (địa hình đã đào, vị trí, chỉ số) giữ nguyên |
| 5.2 | Menu chính đơn giản: New Game / Load Game / Quit | Chọn được, không crash |
| 5.3 | Âm thanh cơ bản: bước chân, đào block, zombie gầm gừ (dùng `AudioStreamPlayer3D` có sẵn của Godot) | Nghe rõ 3 loại âm thanh đúng ngữ cảnh |

---

## 🔥 CHỐT CHẶN SCOPE CREEP

Hết Giai đoạn 5 = **v1.0 hoàn chỉnh, đóng băng tính năng**. Đủ để trả lời câu hỏi ban đầu: "một người + AI có build được không" — câu trả lời sẽ là **có, ở quy mô rút gọn** (không NavMesh phức tạp, không đa luồng, không nhiều loại mob/block như bản gốc 15 năm phát triển).

Không tự thêm: nhiều loại mob, hệ thống thời tiết, Nether/Overworld đa chiều, redstone, đa luồng, multiplayer — trừ khi v1.0 đã chạy ổn và bạn *thật sự* còn hứng thú làm tiếp.
