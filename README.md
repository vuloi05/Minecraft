# Minecraft Clone - Godot Engine 4

Đây là một dự án **Minecraft Clone** được phát triển bằng **Godot Engine 4** với ngôn ngữ GDScript. Dự án nhằm mục đích tái tạo lại các cơ chế cốt lõi của tựa game sinh tồn thế giới mở huyền thoại Minecraft, bao gồm hệ thống Voxel, sinh vật tự động, chu kỳ ngày đêm và tương tác vật lý khối.

## 🚀 Các Tính Năng Đã Hoàn Thiện

### 1. Hệ Thống Thế Giới (Voxel World Generation)
- **Tạo địa hình bằng thuật toán Noise:** Sử dụng `FastNoiseLite` (Simplex Noise) để sinh ra địa hình đồi núi nhấp nhô ngẫu nhiên, tự nhiên và liền mạch.
- **Hệ thống Chunk:** Thế giới được chia thành các Chunk (16x64x16). Cơ chế tự động load/unload Chunk xung quanh người chơi (Render Distance) giúp thế giới có thể mở rộng vô hạn mà không gây giật lag.
- **Cấu trúc sinh học cơ bản:** Địa hình được chia tầng rõ rệt: Cỏ (Grass) ở trên cùng, Đất (Dirt) ở giữa, và Đá (Stone) ở dưới đáy. Có hệ thống sinh Cây ngẫu nhiên (Gỗ và Lá) điểm xuyết trên mặt đất.

### 2. Nhân Vật & Điều Khiển (Player Controller)
- Góc nhìn thứ nhất (FPS) mượt mà với chuột và bàn phím (W, A, S, D, Space để nhảy, Shift để chạy nhanh).
- **Hệ thống Hand Item (Tay cầm):** Nhân vật có cánh tay ảo hiển thị 3D. Hỗ trợ cầm các khối vuông (Block) và các vật phẩm 2D (Cúp đá, Đuốc).
- **Hoạt ảnh (Animation):** Xây dựng hệ thống vật lý khi chặt chém vung tay cực kỳ chân thực. Kết hợp xoay trục Z (chém chéo), gập trục X và dồn lực tới trước trục Z để tạo cảm giác "đập khối" đầm tay hệt như Minecraft bản gốc.

### 3. Tương Tác Khối & Xây Dựng (Block Interaction)
- **Đào/Đặt khối:** Cơ chế RayCast3D cho phép ngắm chính xác vào khối (có con trỏ dấu thập ở giữa màn hình) để phá hủy (Chuột trái) hoặc xây thêm khối (Chuột phải).
- **Wireframe Highlight:** Khối đang được ngắm trúng sẽ hiện viền trắng mỏng xung quanh, giúp người chơi dễ định vị điểm đặt.
- Tối ưu hóa: Chỉ các bề mặt lộ ra ngoài (Exposed Faces) mới được Engine render (thuật toán Greedy Meshing cơ bản), giúp game đạt FPS rất cao.

### 4. Hệ Thống Giao Diện & Túi Đồ (UI/Inventory/Crafting)
- **Túi Đồ Hoàn Chỉnh (Full Inventory):** Nhấn phím `E` hoặc `TAB` để mở màn hình quản lý hành trang.
  - Bao gồm 27 ô chứa đồ dự trữ (Main Inventory) và 9 ô thao tác nhanh (Hotbar).
  - Tích hợp sẵn lưới **Crafting 2x2** bên trong túi đồ để chế tạo nhanh (gỗ ra ván, ván ra que, chế tạo cuốc chim).
  - Hệ thống dữ liệu Crafting được xây dựng chuẩn mực bằng cơ chế **Dictionary (Data-driven)** độc lập và dễ dàng mở rộng.
- **Kéo Thả (Drag & Drop):** Hỗ trợ thao tác kéo thả mượt mà giữa các ô đồ. Đặc biệt hỗ trợ **Chuột phải** để chia đôi số lượng vật phẩm (Split stack) hệt như Minecraft thật.
- **Tooltip Hiện Đại:** Tự động hiển thị tên vật phẩm khi bạn di chuột qua các icon trong Inventory.
- **Thanh Hotbar & Trạng Thái:**
  - Thanh công cụ 9 ô ở cạnh dưới màn hình, hiển thị icon và số lượng vật phẩm.
  - Có thể dùng con lăn chuột (Scroll) hoặc phím số (1-9) để chọn nhanh.
  - Thanh sinh tồn hiển thị theo thời gian thực: **Máu (Tim ♥)** và **Đói (Thịt 🍖)**.
- **Màn hình Loading chờ:** Tích hợp thanh tiến trình tải bản đồ tuyệt đẹp, tránh rơi tự do khi map chưa load.

### 5. Đồ Họa & Ánh Sáng (Graphics & Lighting)
- **Đồ họa Pixel Art:** Áp dụng bộ lọc `TEXTURE_FILTER_NEAREST` lên toàn bộ thế giới để giữ được sự sắc sảo, vỡ hạt đặc trưng của các khối Voxel.
- **Chu kỳ Ngày / Đêm:** Mặt trời (`DirectionalLight3D`) xoay liên tục tạo ra hiệu ứng bình minh, hoàng hôn và đêm tối.
- **Ánh sáng Đuốc (Torch):** Cơ chế đèn `OmniLight3D` màu vàng ấm áp.
- **Cơ chế bóng râm (Shadows):** Đã khắc phục triệt để hiện tượng lọt sáng (Peter Panning) qua các khe khối bằng cách tinh chỉnh `shadow_bias` và `shadow_normal_bias`. Bóng tối trong hang động hoàn toàn đen kịt nếu không có đuốc.
- **Crossed Planes Sprite3D:** Ngọn đuốc cắm dưới mặt đất được vẽ bằng kỹ thuật 2 mặt phẳng 2D vắt chéo nhau (sử dụng `ALPHA_CUT_DISCARD`), chuẩn xác tới từng pixel giống hệt game gốc.

### 6. Quái Vật (Mobs)
- **Zombie AI:** Hệ thống AI tự động sinh ra Zombie vào ban đêm (hiện đang tạm tắt để test xây dựng). Zombie có khả năng dò đường bám theo người chơi và tự động bốc cháy biến mất khi trời sáng.

---

## 🛠️ Trải Nghiệm & Thành Quả
Dự án không chỉ là một bài kiểm tra sức mạnh của Godot 4 đối với thể loại game Voxel, mà còn mang lại một cảm giác chơi vô cùng hoài niệm, chân thực. Từ việc cầm ngọn đuốc thắp sáng hang động đen kịt, đến thao tác cầm chiếc Cúp đá (`Stone Pickaxe`) vung chéo góc đập từng khối đất, mọi thứ đều hoạt động cực kỳ mượt mà.

Sự tỉ mỉ trong việc căn chỉnh tia sáng đổ bóng (Shadow mapping) và góc nghiêng của công cụ trên tay đã chứng minh được tính hoàn thiện cao trong trải nghiệm thị giác của bản clone này!
