# **ImageSearch UDF & DLL Hiệu Suất Cao cho AutoIt**

Dự án này cung cấp một UDF (User Defined Function) và hai phiên bản DLL (Dynamic-Link Library) được tối ưu hóa cao, dành cho việc tìm kiếm hình ảnh trên màn hình một cách nhanh chóng và linh hoạt bằng AutoIt.

Đây là giải pháp thay thế mạnh mẽ cho các hàm tìm kiếm hình ảnh thông thường, mang lại tốc độ vượt trội, đặc biệt trên các CPU hiện đại, nhờ vào việc sử dụng các tập lệnh SIMD tiên tiến.

## **✨ Các Tính Năng Chính**

* **Tốc Độ Vượt Trội:** Phiên bản hiện đại sử dụng tập lệnh **AVX2** để tăng tốc độ tìm kiếm lên nhiều lần so với các phương pháp truyền thống.  
* **Hai Phiên Bản DLL:** Cung cấp cả phiên bản hiện đại (tối ưu cho tốc độ) và phiên bản tương thích (hỗ trợ Windows XP).  
* **Tìm Kiếm Đa Hình Ảnh:** Tìm kiếm nhiều tệp ảnh cùng lúc chỉ bằng một lệnh gọi hàm, các đường dẫn được phân tách bằng dấu gạch đứng (|).  
* **Tìm Kiếm Theo Tỷ Lệ (Scaling):** Tự động tìm kiếm một hình ảnh ở nhiều kích thước khác nhau (ví dụ: từ 80% đến 120% kích thước gốc).  
* **Dung Sai Màu Sắc:** Tìm thấy hình ảnh ngay cả khi có sự khác biệt nhỏ về màu sắc bằng cách thiết lập giá trị dung sai (từ 0 đến 255).  
* **Hỗ Trợ Màu Trong Suốt:** Chỉ định một màu trong ảnh nguồn để bỏ qua khi tìm kiếm.  
* **Xử Lý Kết Quả Linh Hoạt:**  
  * Tìm và trả về kết quả đầu tiên.  
  * Tìm và trả về tất cả các kết quả trên màn hình.  
  * Giới hạn số lượng kết quả tối đa.  
* **Cơ Chế Nạp DLL Thông Minh (Hybrid):** UDF ưu tiên sử dụng DLL bên ngoài để có hiệu năng cao nhất và tự động chuyển sang DLL nhúng sẵn để đảm bảo script luôn hoạt động.  
* **Hỗ Trợ Unicode:** Hoạt động hoàn hảo với các đường dẫn tệp chứa ký tự Unicode.  
* **An Toàn Luồng (Thread-Safe):** DLL được thiết kế để hoạt động ổn định trong các kịch bản đa luồng.  
* **Thông Tin Gỡ Lỗi (Debug):** Cung cấp tùy chọn trả về chuỗi thông tin chi tiết về quá trình tìm kiếm để dễ dàng chẩn đoán lỗi.

## **🚀 Hai Phiên Bản DLL**

Dự án cung cấp hai phiên bản DLL để đáp ứng các nhu cầu khác nhau:

### **1. ImageSearch_x86.dll ImageSearch_x64.dll (Phiên bản Hiện đại)**
(Được đính kèm trong cùng thư mục UDF - Vì tệp DLL hỗ trợ AVX2 có kích thước lớn nên không phù hợp để nhúng vào tập lệnh)

Đây là phiên bản được khuyến nghị cho hầu hết người dùng.

* **Điểm mạnh:**  
  * **Hỗ trợ AVX2:** Tận dụng tập lệnh Advanced Vector Extensions 2 trên các CPU hiện đại để xử lý song song nhiều pixel cùng lúc, mang lại tốc độ tìm kiếm cực nhanh.  
  * Được xây dựng bằng C++ hiện đại, đảm bảo tính ổn định và hiệu quả.  
* **Hạn chế:**  
  * Không tương thích với Windows XP.  
* **Sử dụng khi:** Bạn cần hiệu suất tối đa trên các hệ điều hành Windows 7, 8, 10, 11.

### **2. ImageSearch_xp.dll (Phiên bản Tương thích - Legacy)**
(Đã được nhúng trong mã UDF)
Phiên bản này được tạo ra để đảm bảo khả năng tương thích ngược.

* **Điểm mạnh:**  
  * **Tương thích Windows XP:** Hoạt động tốt trên hệ điều hành Windows XP (SP3).  
* **Hạn chế:**  
  * **Không hỗ trợ AVX2:** Tốc độ tìm kiếm sẽ chậm hơn đáng kể so với phiên bản hiện đại trên các CPU có hỗ trợ AVX2.  
* **Sử dụng khi:** Script của bạn bắt buộc phải chạy trên môi trường Windows XP.

## **⚙️ Cơ Chế Hoạt Động Của UDF**

Tệp ImageSearch_UDF.au3 sử dụng cơ chế nạp DLL "lai" (hybrid) rất thông minh:

1. **Ưu tiên DLL bên ngoài:** Khi hàm _ImageSearch được gọi, UDF sẽ tìm tệp ImageSearch_x86.dll hoặc ImageSearch_x64.dll trong cùng thư mục với script (@ScriptDir). Nếu tìm thấy, nó sẽ sử dụng tệp này để có được hiệu suất tốt nhất (với AVX2 nếu có thể).  
2. **Dự phòng DLL nhúng:** Nếu không tìm thấy tệp DLL bên ngoài, UDF sẽ tự động giải nén và sử dụng một phiên bản DLL **tương thích (legacy, không AVX2)** đã được nhúng sẵn bên trong nó dưới dạng chuỗi hex.

➡️ **Điều này đảm bảo rằng script của bạn luôn có thể chạy được**, ngay cả khi bạn quên sao chép tệp DLL, nhưng để đạt tốc độ cao nhất, hãy luôn đặt ImageSearch_x86.dll và ImageSearch_x64.dll (phiên bản hiện đại) bên cạnh script của bạn.

## **📦 Cài Đặt**

1. **Đặt tệp DLL:** Sao chép ImageSearch_x86.dll và ImageSearch_x64.dll (phiên bản hiện đại) vào cùng thư mục với tệp script AutoIt của bạn. Nếu dùng trên Windows XP, Dll đã được tích hợp trong mã UDF (KHÔNG CẦN SAO CHÉP DLL).  
2. **Thêm UDF vào script:** Sử dụng dòng lệnh #include <ImageSearch_UDF.au3> trong script của bạn.

## **📖 Hướng Dẫn Sử Dụng (API)**

Hàm chính để thực hiện việc tìm kiếm hình ảnh.

### **_ImageSearch($sImageFile, [$iLeft = 0], [$iTop = 0], [$iRight = 0], [$iBottom = 0], [$iTolerance = 10], [$iTransparent = 0xFFFFFFFF], [$iMultiResults = 0], [$iCenterPOS = 1], [$iReturnDebug = 0], [$fMinScale = 1.0], [$fMaxScale = 1.0], [$fScaleStep = 0.1], [$iFindAllOccurrences = 0])**

**Các Tham Số**

| Tham số | Kiểu | Mặc định | Mô tả |
| :---- | :---- | :---- | :---- |
| $sImageFile | String | - | Đường dẫn đến tệp ảnh. Để tìm nhiều ảnh, phân tách bằng dấu ` |
| $iLeft | Int | 0 | Tọa độ trái của vùng tìm kiếm. 0 mặc định là toàn màn hình. |
| $iTop | Int | 0 | Tọa độ trên của vùng tìm kiếm. 0 mặc định là toàn màn hình. |
| $iRight | Int | 0 | Tọa độ phải của vùng tìm kiếm. 0 mặc định là toàn màn hình. |
| $iBottom | Int | 0 | Tọa độ dưới của vùng tìm kiếm. 0 mặc định là toàn màn hình. |
| $iTolerance | Int | 10 | Dung sai màu (0-255). Giá trị càng cao, sự khác biệt màu sắc cho phép càng lớn. |
| $iTransparent | Int | 0xFFFFFFFF | Màu (định dạng 0xRRGGBB) cần bỏ qua trong ảnh nguồn. 0xFFFFFFFF có nghĩa là không có màu trong suốt. |
| $iMultiResults | Int | 0 | Số lượng kết quả tối đa cần trả về. 0 có nghĩa là không giới hạn. |
| $iCenterPOS | Bool | 1 (True) | Nếu True, tọa độ X/Y trả về sẽ là tâm của ảnh. Nếu False, sẽ là góc trên bên trái. |
| $iReturnDebug | Bool | 0 (False) | Nếu True, hàm sẽ trả về một chuỗi thông tin gỡ lỗi thay vì mảng kết quả. |
| $fMinScale | Float | 1.0 | Tỷ lệ nhỏ nhất để tìm kiếm (ví dụ: 0.8 cho 80%). Phải >= 0.1. |
| $fMaxScale | Float | 1.0 | Tỷ lệ lớn nhất để tìm kiếm (ví dụ: 1.2 cho 120%). |
| $fScaleStep | Float | 0.1 | Bước nhảy tỷ lệ khi tìm kiếm giữa min và max. Phải >= 0.01. |
| $iFindAllOccurrences | Bool | 0 (False) | Nếu False, dừng tìm kiếm sau khi có kết quả đầu tiên. Nếu True, tìm tất cả các kết quả có thể có. |

**Giá Trị Trả Về**

* **Thành công:** Trả về một mảng 2D chứa tọa độ của các ảnh tìm thấy.  
  * $aResult[0][0] = Số lượng kết quả tìm thấy.  
  * $aResult[1] đến $aResult[$aResult[0][0]] = Một mảng cho mỗi kết quả.  
  * $aResult[$i][0] = Tọa độ X  
  * $aResult[$i][1] = Tọa độ Y  
  * $aResult[$i][2] = Chiều rộng của ảnh tìm thấy  
  * $aResult[$i][3] = Chiều cao của ảnh tìm thấy  
* **Thất bại / Không tìm thấy:** Thiết lập @error thành 1 và trả về 0.  
* **Chế độ Debug:** Nếu $iReturnDebug là True, trả về một chuỗi chứa thông tin chi tiết về lần tìm kiếm cuối cùng.

## **💻 Ví Dụ**

### **Ví dụ 1: Tìm kiếm cơ bản**

Tìm sự xuất hiện đầu tiên của button.png trên màn hình.
```
#include <ImageSearch_UDF.au3>

Local $aResult = _ImageSearch("C:\images\button.png")

If @error Then  
    MsgBox(48, "Error", "Image not found on screen.")  
Else  
    Local $iCount = $aResult[0][0]  
    Local $iX = $aResult[1][0]  
    Local $iY = $aResult[1][1]  
    MsgBox(64, "Success", "Found " & $iCount & " image(s). First match is at: " & $iX & ", " & $iY)  
    MouseMove($iX, $iY, 20) ; Move mouse to the center of the found image  
EndIf
```
### **Ví dụ 2: Tìm kiếm nâng cao (Đa ảnh, dung sai, tỷ lệ)**

Tìm icon1.png hoặc icon2.png trong một vùng cụ thể, với dung sai 20 và tỷ lệ từ 90% đến 110%. Tìm tất cả các kết quả.
```
#include <ImageSearch_UDF.au3>

Local $sImages = "icon1.png|icon2.png"  
Local $iTolerance = 20  
Local $fMinScale = 0.9  
Local $fMaxScale = 1.1  
Local $fStep = 0.05

Local $aResult = _ImageSearch($sImages, 500, 300, 1200, 800, $iTolerance, 0xFFFFFFFF, 0, True, False, $fMinScale, $fMaxScale, $fStep, True)

If @error Then  
    MsgBox(48, "Error", "No matching images found in the specified region.")  
Else  
    Local $iCount = $aResult[0][0]  
    ConsoleWrite("Found " & $iCount & " total matches." & @CRLF)

    For $i = 1 To $iCount  
        ConsoleWrite("Match #" & $i & ": X=" & $aResult[$i][0] & ", Y=" & $aResult[$i][1] & ", W=" & $aResult[$i][2] & ", H=" & $aResult[$i][3] & @CRLF)  
    Next  
EndIf
```
### **Ví dụ 3: Sử dụng chế độ Debug**

Để chẩn đoán sự cố, hãy sử dụng tham số $iReturnDebug.
```
#include <ImageSearch_UDF.au3>

Local $2dDLLResult = _ImageSearch("image_not_exist.png", 0, 0, 0, 0, 10, 0xFFFFFFFF, 0, True, True)
ConsoleWrite(">> DLL Return: " & $g_sLastDllReturn & @CRLF)
; Ví dụ output: {0}[No Match Found] | DEBUG: File=image_not_exist.png, Rect=(0,0,1920,1080), Tol=10, Trans=0xffffffff, Multi=0, Center=1, FindAll=0, AVX2=true, Scale=(1.00,1.00,0.10)
```

## **Tác giả**

* **Tác giả:** Đào Văn Trong - TRONG.PRO  
