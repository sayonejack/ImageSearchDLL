# **ImageSearch UDF cho AutoIt**

## **Tổng Quan**

Đây là một Hàm do Người dùng Định nghĩa (UDF) mạnh mẽ, hiệu suất cao cho AutoIt, được thiết kế để tìm kiếm hình ảnh trên màn hình. Nó tận dụng một tệp DLL tùy chỉnh để xử lý, giúp tốc độ tìm kiếm nhanh hơn đáng kể so với các hàm tìm kiếm pixel/hình ảnh gốc của AutoIt.

UDF được thiết kế để hoạt động ổn định, linh hoạt và dễ dàng tích hợp. Một tính năng chính là cơ chế tải DLL "lai" (hybrid), giúp kịch bản trở nên khép kín và đơn giản để phân phối.

**Tác giả:** Đào Văn Trong \- TRONG.PRO

**Phiên bản:** 2025.07.22

## **Các Tính Năng**

* **Tìm kiếm tốc độ cao**: Sử dụng một DLL đã được biên dịch sẵn (x86 và x64) để nhận dạng hình ảnh nhanh chóng, lý tưởng cho các tác vụ tự động hóa đòi hỏi tốc độ.  
* **Cơ chế tải DLL "lai" (Hybrid)**: UDF sẽ ưu tiên sử dụng một tệp DLL cục bộ trong thư mục của kịch bản, nhưng sẽ tự động chuyển sang phiên bản nhúng, khép kín nếu không tìm thấy tệp cục bộ. Điều này có nghĩa là bạn chỉ cần thêm tệp UDF này vào dự án của mình.  
* **Tìm kiếm theo khu vực**: Tìm kiếm trên toàn bộ màn hình hoặc chỉ định một vùng hình chữ nhật cụ thể để cải thiện hiệu suất và độ chính xác.  
* **Dung sai màu**: Tìm kiếm các hình ảnh không hoàn toàn khớp chính xác bằng cách chỉ định một giá trị dung sai cho các biến thể màu sắc.  
* **Hỗ trợ co giãn ảnh (Scaling)**: Phát hiện các hình ảnh đã bị thay đổi kích thước trên màn hình bằng cách chỉ định một phạm vi tỷ lệ để kiểm tra (ví dụ: tìm một biểu tượng ở kích thước từ 80% đến 120% so với kích thước gốc).  
* **Tìm kiếm nhiều ảnh**: Tìm kiếm nhiều hình ảnh trong một lệnh duy nhất. Hàm có thể trả về vị trí của hình ảnh đầu tiên được tìm thấy hoặc tất cả các lần xuất hiện của tất cả các hình ảnh được chỉ định.  
* **Giá trị trả về chi tiết**: Trả về một mảng có cấu trúc với số lượng và tọa độ của các hình ảnh được tìm thấy. Hỗ trợ cả định dạng kết quả đơn (mảng 1D) và nhiều kết quả (mảng 2D).  
* **Xử lý lỗi mạnh mẽ**: Thiết lập macro @error của AutoIt với các mã lỗi cụ thể để dễ dàng chẩn đoán các lần tìm kiếm không thành công.  
* **Tự động dọn dẹp**: Khi sử dụng DLL nhúng, tệp tạm thời sẽ tự động bị xóa khi kịch bản kết thúc.

## **Cách Hoạt Động: Cơ Chế Tải DLL "Lai"**

UDF sử dụng một phương pháp "lai" thông minh để quản lý tệp DLL cốt lõi của nó:

1. **Ưu tiên DLL cục bộ**: Đầu tiên, nó sẽ kiểm tra xem có tệp ImageSearch\_x64.dll hoặc ImageSearch\_x86.dll trong cùng thư mục với kịch bản của bạn (@ScriptDir) hay không. Điều này cho phép bạn dễ dàng cập nhật DLL mà không cần sửa đổi mã UDF.  
2. **Sử dụng DLL nhúng làm phương án dự phòng**: Nếu không tìm thấy DLL cục bộ, UDF sẽ tự động giải nén một phiên bản DLL được mã hóa dưới dạng hex và nhúng sẵn bên trong nó vào thư mục tạm của người dùng (@TempDir) và tải nó từ đó.  
3. **Dọn dẹp**: Tệp DLL tạm thời sẽ tự động được xóa khi kịch bản kết thúc, đảm bảo không để lại tệp không cần thiết trên hệ thống.

## **Tham Khảo Các Hàm**

### **\_ImageSearch()**

Tìm kiếm một hình ảnh trên toàn bộ màn hình. Đây là một hàm bao (wrapper) đơn giản hóa cho \_ImageSearch\_Area.

Cú pháp:  
\_ImageSearch($sImagePath\[, $iTolerance \= 0\[, $iCenterPos \= 1\[, $iTransparent \= \-1\[, $bReturn2D \= False\]\]\]\])

* $sImagePath: Đường dẫn đầy đủ đến tệp hình ảnh cần tìm.  
* $iTolerance (Tùy chọn): Dung sai cho phép đối với sự thay đổi màu sắc (0-255). 0 là khớp chính xác. Mặc định là 0\.  
* $iCenterPos (Tùy chọn): Nếu là 1, trả về tọa độ trung tâm của hình ảnh được tìm thấy. Nếu là 0, trả về tọa độ góc trên bên trái. Mặc định là 1\.  
* $iTransparent (Tùy chọn): Một màu được coi là trong suốt (ví dụ: 0xFF00FF). Mặc định là \-1 (không có).  
* $bReturn2D (Tùy chọn): Nếu là True, trả về một mảng 2D với tất cả các kết quả khớp. Nếu là False, trả về một mảng 1D với kết quả khớp đầu tiên. Mặc định là False.

**Giá trị trả về:**

* **Thành công**:  
  * Nếu $bReturn2D là False: Một mảng 1D \[số\_lượng\_khớp, x, y\].  
  * Nếu $bReturn2D là True: Một mảng 2D trong đó \[0\]\[0\] là số lượng khớp. Mỗi hàng tiếp theo là \[chỉ\_số, x, y, chiều\_rộng, chiều\_cao\].  
* **Thất bại**: Một mảng trong đó phần tử đầu tiên là mã lỗi (\<= 0).

### **\_ImageSearch\_Area()**

Tìm kiếm một hình ảnh trong một vùng hình chữ nhật được chỉ định trên màn hình. Đây là hàm cốt lõi với tất cả các tùy chọn có sẵn.

Cú pháp:  
\_ImageSearch\_Area($sImageFile\[, $iLeft \= 0\[, $iTop \= 0\[, $iRight \= @DesktopWidth\[, $iBottom \= @DesktopHeight\[, ...\]\]\]\]\])

* $sImageFile: Đường dẫn đầy đủ đến tệp hình ảnh. Có thể cung cấp nhiều đường dẫn, phân tách bằng dấu |.  
* $iLeft, $iTop, $iRight, $iBottom (Tùy chọn): Tọa độ của vùng tìm kiếm.  
* $iTolerance (Tùy chọn): Dung sai biến thể màu (0-255).  
* $iTransparent (Tùy chọn): Giá trị màu trong suốt.  
* $iMultiResults (Tùy chọn): Số lượng kết quả tối đa cần tìm. Mặc định là 1\.  
* $iCenterPos (Tùy chọn): Trả về tọa độ trung tâm (1) hoặc góc trên bên trái (0).  
* $fMinScale, $fMaxScale (Tùy chọn): Hệ số co giãn tối thiểu và tối đa để kiểm tra (ví dụ: 0.8 cho 80%, 1.2 cho 120%). Mặc định là 1.0.  
* $fScaleStep (Tùy chọn): Bước tăng tỷ lệ từ min đến max. Mặc định là 0.1.  
* $bReturn2D (Tùy chọn): Trả về mảng 2D với tất cả các kết quả (True) hoặc mảng 1D với kết quả đầu tiên (False).

**Giá trị trả về:**

* Tương tự như \_ImageSearch().

### **\_ImageSearch\_Wait() & \_ImageSearch\_WaitArea()**

Các hàm này thực hiện tìm kiếm hình ảnh lặp đi lặp lại cho đến khi hình ảnh được tìm thấy hoặc hết thời gian chờ.

Cú pháp:  
\_ImageSearch\_Wait($iTimeOut, $sImagePath, ...)  
\_ImageSearch\_WaitArea($iTimeOut, $sImageFile, ...)

* $iTimeOut: Thời gian chờ tối đa, tính bằng mili giây.  
* Các tham số còn lại tương tự như \_ImageSearch() và \_ImageSearch\_Area().

**Giá trị trả về:**

* Trả về kết quả của lần tìm thấy thành công đầu tiên, hoặc kết quả cuối cùng (chỉ ra thất bại) nếu hết thời gian chờ.

## **Ví Dụ Sử Dụng**

### **Bắt Đầu Nhanh**

Để sử dụng UDF, chỉ cần thêm nó vào kịch bản của bạn.

\#include "ImageSearch\_UDF.au3"

; Đường dẫn đến hình ảnh bạn muốn tìm  
Local $imagePath \= "path\\to\\your\\image.bmp"

; Tìm kiếm hình ảnh trên toàn bộ màn hình  
Local $result \= \_ImageSearch($imagePath)

; Kiểm tra xem hình ảnh có được tìm thấy không  
If $result\[0\] \> 0 Then  
    ; $result\[1\] \= Tọa độ X, $result\[2\] \= Tọa độ Y  
    ConsoleWrite("Đã tìm thấy hình ảnh tại: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
    MouseMove($result\[1\], $result\[2\])  
Else  
    ConsoleWrite("Không tìm thấy hình ảnh. @error: " & @error & @CRLF)  
EndIf

### **Ví dụ 1: Tìm kiếm trong một khu vực cụ thể**

Ví dụ này tìm kiếm một hình ảnh chỉ trong khu vực 800x600 ở góc trên bên trái màn hình.

\#include "ImageSearch\_UDF.au3"

Local $imagePath \= "path\\to\\image.bmp"  
Local $iLeft \= 0, $iTop \= 0, $iRight \= 800, $iBottom \= 600

Local $result \= \_ImageSearch\_Area($imagePath, $iLeft, $iTop, $iRight, $iBottom)

If $result\[0\] \> 0 Then  
    ConsoleWrite("Đã tìm thấy hình ảnh trong khu vực chỉ định tại: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
EndIf

### **Ví dụ 2: Tìm kiếm nhiều ảnh với tính năng co giãn**

Ví dụ này tìm kiếm Search\_1.bmp hoặc Search\_2.bmp. Nó cũng kiểm tra các phiên bản co giãn của hình ảnh trong khoảng từ 80% đến 120% kích thước gốc và trả về tất cả các kết quả khớp được tìm thấy.

\#include "ImageSearch\_UDF.au3"

Local $image1 \= "Search\_1.bmp"  
Local $image2 \= "Search\_2.bmp"  
Local $imageList \= $image1 & '|' & $image2

; Tham số cuối cùng (1) đặt $bReturn2D thành True  
Local $aResult \= \_ImageSearch\_Area($imageList, 0, 0, @DesktopWidth, @DesktopHeight, 0, \-1, 99, 1, 1, 0.8, 1.2, 0.1, 1\)

If $aResult\[0\]\[0\] \> 0 Then  
    ConsoleWrite("Tìm thấy tổng cộng " & $aResult\[0\]\[0\] & " kết quả." & @CRLF)  
    For $i \= 1 To $aResult\[0\]\[0\]  
        Local $x \= $aResult\[$i\]\[1\]  
        Local $y \= $aResult\[$i\]\[2\]  
        ConsoleWrite("Kết quả " & $i & " được tìm thấy tại: " & $x & ", " & $y & @CRLF)  
    Next  
Else  
    ConsoleWrite("Không tìm thấy hình ảnh nào." & @CRLF)  
EndIf

### **Ví dụ 3: Sử dụng dung sai màu**

Ví dụ này tìm kiếm một hình ảnh, cho phép sự thay đổi màu sắc lên đến 20\. Điều này hữu ích nếu hình ảnh trên màn hình có một chút nhiễu do nén hoặc khác biệt về màu sắc.

\#include "ImageSearch\_UDF.au3"

Local $imagePath \= "path\\to\\image.bmp"

; Tìm kiếm với dung sai là 20  
Local $result \= \_ImageSearch($imagePath, 20\)

If $result\[0\] \> 0 Then  
    ConsoleWrite("Đã tìm thấy hình ảnh với dung sai tại: " & $result\[1\] & ", " & $result\[2\] & @CRLF)  
EndIf  


## **Tham chiếu API**

### **ImageSearch.DLL**

char* WINAPI ImageSearch(
    char* sImageFile,
    int iLeft, int iTop, int iRight, int iBottom,
    int iTolerance, int iTransparent,
    int iMultiResults, int iCenterPOS, int iReturnDebug,
    float fMinScale, float fMaxScale, float fScaleStep
);

**Tham số:**

* sImageFile (char*): Một chuỗi được phân tách bằng dấu gạch đứng (|) chứa các đường dẫn đến tệp hình ảnh cần tìm.
* iLeft, iTop, iRight, iBottom (int): Tọa độ của hình chữ nhật tìm kiếm. Nếu iRight hoặc iBottom bằng 0, sẽ sử dụng chiều rộng/chiều cao của màn hình.
* iTolerance (int): Dung sai màu (0-255). 0 có nghĩa là khớp chính xác.
* iTransparent (int): Giá trị COLORREF (ví dụ: 0xRRGGBB) được coi là trong suốt. Sử dụng CLR_NONE nếu không có.
* iMultiResults (int): Số lượng kết quả tối đa cần tìm. Nếu 0, tìm tất cả.
* iCenterPOS (int): Nếu là 1, trả về tọa độ trung tâm của hình ảnh được tìm thấy. Nếu không, trả về góc trên cùng bên trái.
* iReturnDebug (int): Nếu là 1, nối một chuỗi gỡ lỗi vào kết quả.
* fMinScale, fMaxScale, fScaleStep (float): Các yếu tố tỷ lệ để kiểm tra (ví dụ: 0.8, 1.2, 0.1).

**Giá trị trả về:**

* Một con trỏ char* tĩnh đến một chuỗi được định dạng.
* Thành công: "{match_count}[x|y|w|h,x2|y2|w2|h2,...]"
* Không tìm thấy: "{0}[No Match Found]"
* Lỗi: "{error_code}[error_message]"