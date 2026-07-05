extends DirectionalLight3D

# Tốc độ quay của Mặt trời (chu kỳ Ngày/Đêm)
# 0.1 radian/s = mất khoảng 60s cho 1 vòng (1 ngày)
var time_speed = 0.1

func _process(delta):
	rotate_x(time_speed * delta)
