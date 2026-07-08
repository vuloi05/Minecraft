# Minecraft Clone - Godot Engine 4

Đây là một dự án **Minecraft Clone** được phát triển hoàn toàn bằng **Godot Engine 4** với ngôn ngữ GDScript. Dự án nhằm mục đích tái tạo lại các cơ chế cốt lõi của tựa game sinh tồn thế giới mở huyền thoại Minecraft, xây dựng một kiến trúc Voxel mạnh mẽ và một hệ thống Gameplay Data-Driven linh hoạt.

## 💻 Công Nghệ & Kiến Trúc
- **Engine:** Godot Engine 4.x
- **Ngôn Ngữ Lập Trình:** GDScript (Lộ trình tương lai: Sử dụng C# hoặc GDExtension C++ cho thuật toán sinh lưới - Mesh Generation - để tối ưu hóa tối đa hiệu năng của Voxel).
- **Kiến Trúc Voxel:** Xử lý lưới 3D động với `SurfaceTool`, `ArrayMesh`, tối ưu hóa hiệu năng cực đại với hệ thống đa luồng `WorkerThreadPool`.
- **Dữ Liệu & Logic (Data-Driven):** Sử dụng định dạng `JSON` để lưu trữ thuộc tính khối, công thức chế tạo, giúp game dễ dàng mở rộng, modding mà không cần chỉnh sửa mã nguồn.
- **Xử Lý Tài Nguyên (Asset Pipeline):** Tích hợp Script `Python` (sử dụng thư viện Pillow) để tự động hóa quá trình cắt ghép hình ảnh thành Texture Atlas.

## 🚀 Các Tính Năng Đã Hoàn Thiện

### 1. Hệ Thống Thế Giới (Voxel World Generation & Rendering)
- **Thuật toán Noise & Sinh địa hình:** Sử dụng `FastNoiseLite` (Simplex Noise) để sinh ra địa hình đồi núi, thung lũng một cách tự nhiên. Tích hợp `cave_noise` 3D để tạo ra hệ thống hang động ngầm phức tạp.
- **Hệ thống Chunk Đa luồng (Multi-threading):** Thế giới được chia thành các Chunk (16x64x16). Quá trình sinh khối (Generate) và xây dựng lưới (Meshing) được xử lý hoàn toàn trên các luồng ngầm (WorkerThreadPool), đảm bảo game luôn mượt mà kể cả khi load địa hình mới.
- **Kiến trúc Lưới Kép (Dual Mesh Architecture):**
  - **Lưới Đặc (Opaque Mesh):** Dành cho đất, đá, gỗ... sử dụng vật liệu `TRANSPARENCY_ALPHA_SCISSOR` để tối ưu hóa hiệu năng và đổ bóng (Shadows) chuẩn xác.
  - **Lưới Trong Suốt (Translucent Mesh):** Dành riêng cho các khối bán trong suốt (như Nước). Khắc phục triệt để lỗi đè hình (Z-sorting) thường gặp trong làm game Voxel. Cả hai lưới chồng lên nhau tạo ra thế giới vô cùng chân thực.
- **Tối ưu hóa tham lam (Greedy Meshing cơ bản):** Chỉ các bề mặt lộ ra ngoài (Exposed Faces) và không bị khối bên cạnh che khuất mới được render, giúp game đạt FPS rất cao.

### 2. Nhân Vật & Vật Lý (Player Controller)
- **Góc nhìn thứ nhất (FPS):** Mượt mà với chuột và bàn phím (W, A, S, D, Space để nhảy).
- **Hệ thống Tay cầm 3D (Hand Item):** Hiển thị khối hoặc công cụ (Tool) đang cầm. Tự động chuyển đổi giữa khối vuông 3D (Block) và Sprite nghiêng 2D (Cúp đá, Đuốc) tùy theo vật phẩm. Hoạt ảnh vung tay khi đập khối được tinh chỉnh cực kỳ có lực.
- **Tương Tác Khối (RayCast3D):** Có Wireframe (viền đen/trắng) hiển thị khối đang nhắm tới. Hỗ trợ đặt và phá khối.
- **Vật lý Bơi Lội & Nước:** 
  - Khối nước không có hộp va chạm (Collision). 
  - Khi đi vào nước, tốc độ di chuyển bị giảm 50% (Water Drag). 
  - Có thể giữ Space để nổi dần lên (Bơi lội). 
  - Trọng lực rơi được giảm thiểu để mô phỏng lực đẩy của nước.

### 3. Hệ Thống Vật Phẩm & Chế Tạo (Data-Driven Gameplay)
- **Data-Driven Architecture:** Toàn bộ dữ liệu của game được quản lý bên ngoài Code thông qua JSON (`blocks_data.json` và `crafting_recipes.json`). Điều này giúp thêm khối mới, công cụ mới, hay công thức chế tạo mới mà không cần chạm vào 1 dòng Code nào!
- **Hệ Thống Chế Tạo (Crafting):** 
  - Hỗ trợ lưới 2x2 (trong túi đồ) và 3x3 (Bàn chế tạo - Crafting Table). 
  - Thuật toán nhận diện công thức thông minh (Bounding Box Matching), cho phép bạn xếp nguyên liệu ở bất kỳ góc nào của lưới 3x3 miễn là đúng hình dạng.
- **Hệ Thống Nung (Smelting):** 
  - Lò nung (Furnace) hoàn chỉnh với 3 khe: Nguyên liệu, Nhiên liệu (Than, Gỗ) và Sản phẩm.
  - Thanh tiến trình lửa (Fuel) và mũi tên nung (Progress) hoạt động theo thời gian thực. Hỗ trợ nung ra Kính (Glass), Sắt (Iron), v.v.
- **Vật Phẩm Rơi (Item Drops):** Phá khối sẽ sinh ra vật phẩm vật lý 3D nhỏ rơi trên mặt đất, lơ lửng và xoay tròn (Bobbing) y hệt game gốc. Hỗ trợ gom đồ khi bước lại gần.

### 4. Hệ Thống Khai Thác & Công Cụ (Mining & Tool Tiers)
- Áp dụng hệ thống cấp độ công cụ (Tool Tiers): Gỗ -> Đá -> Sắt -> Kim Cương.
- Mỗi khối đều có "Công cụ khắc chế" (Ví dụ: Đá cần Cúp, Gỗ cần Rìu, Đất cần Xẻng) và "Độ cứng" (Hardness).
- Khai thác bằng tay không sẽ cực kỳ chậm. Dùng đúng công cụ sẽ tăng tốc độ theo cấp độ (Kim Cương đào đá nhanh như chớp).
- Nếu dùng sai công cụ hoặc công cụ cấp thấp (vd: dùng Cúp gỗ đào quặng Kim cương), khối sẽ vỡ nhưng **không rớt ra vật phẩm** (No drops).

### 5. Vật Lý Khối Phức Tạp (Block Physics)
- **Cát & Sỏi (Gravity Blocks):** Tự động rơi xuống nếu bên dưới không có khối đỡ. Nếu đè lên người chơi, người chơi sẽ bị mất máu ngạt thở.
- **Nước Chảy (Water Spreading):** 
  - Áp dụng kỹ thuật ID Phân Cấp (Decay IDs: `101 -> 102 -> 103`) để tạo dòng chảy tối đa 3 block ngang, ngăn chặn ngập lụt vô tận mà không tốn RAM lưu trữ Metadata.
  - Nước sẽ ưu tiên rơi thẳng xuống, và chỉ chảy lan ra 4 hướng khi chạm mặt phẳng cứng. Thác nước có chiều cao giảm dần vô cùng đẹp mắt.

### 6. Giao Diện Người Dùng (UI & HUD)
- **Inventory & Hotbar:** 
  - Giao diện thiết kế chuẩn Minecraft với hệ thống Texture xịn (Heart, Hunger, Hotbar, Slots).
  - Tích hợp số lượng vật phẩm (Stacking) lên đến 64.
- **Thao tác Click-to-Hold chuẩn mực:** 
  - Chuột trái: Nhấc toàn bộ / Đặt toàn bộ / Hoán đổi vị trí đồ.
  - Chuột phải: Nhấc 1/2 số lượng / Nhả 1 vật phẩm duy nhất (cực kỳ hữu ích khi rải nguyên liệu chế tạo).
- **Thanh Sinh Tồn:** Hiển thị 10 Trái Tim (Máu) và 10 Đùi Gà (Đói). 
- **Chỉ số Đói (Hunger):** Càng hoạt động, đói càng giảm. Khi hết đồ ăn, người chơi sẽ mất máu dần cho đến chết. Hỗ trợ ngã từ trên cao mất máu (Fall Damage).

### 7. Đồ Họa & Ánh Sáng (Graphics & Lighting)
- **Đồ họa Pixel Art:** Áp dụng bộ lọc `TEXTURE_FILTER_NEAREST` kết hợp với hệ thống Texture Atlas tự động ghép ảnh (Python Script).
- **Chu kỳ Ngày / Đêm:** Mặt trời xoay liên tục tạo ra hiệu ứng bình minh, hoàng hôn và đêm tối.
- **Ánh sáng Đuốc (Torch):** Cơ chế đèn `OmniLight3D` màu vàng ấm áp, xử lý tinh xảo để bóng râm đổ chuẩn xác, không bị lọt sáng qua khe khối (Peter Panning). Đuốc cắm đất được vẽ bằng kỹ thuật 2 mặt phẳng vắt chéo (Crossed Planes).

---

## 🛠️ Trải Nghiệm & Thành Quả
Dự án không chỉ là một bài kiểm tra sức mạnh của Godot 4 đối với thể loại game Voxel, mà còn là một minh chứng cho thấy một kiến trúc dữ liệu thông minh (Data-Driven) có thể biến việc lập trình game trở nên linh hoạt như thế nào.

Từ những tương tác vật lý nhỏ như dòng nước chảy lan ra, hạt cát rơi tự do, cho đến hệ thống phân cấp công cụ khai thác và UI kéo thả cực kỳ mượt mà, dự án này đã tái hiện thành công "linh hồn" của Minecraft bản gốc!
