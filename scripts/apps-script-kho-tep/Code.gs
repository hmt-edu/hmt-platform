/**
 * Kho tệp HMT trên Google Drive qua Google Apps Script (F-23-53).
 * Chạy bằng quyền tài khoản chủ Drive («Thực thi với tư cách: Tôi»). Chỉ Edge Function của HMT gọi, kèm MẬT KHẨU DÙNG CHUNG.
 * Chỉ làm 5 việc: ping (kiểm kết nối), quota (dung lượng), save (lưu), read (đọc), remove (xoá vĩnh viễn).
 * RÀNG BUỘC CỨNG: mọi thao tác chỉ trong thư mục gốc ROOT_FOLDER_ID (tài khoản còn giữ sao lưu đêm và thư: không được chạm gì ngoài thư mục này).
 * Thuộc tính tập lệnh cần có: SECRET (mật khẩu dùng chung), ROOT_FOLDER_ID (id thư mục gốc của kho tệp).
 * Cần bật dịch vụ nâng cao «Drive API» (tên định danh Drive) để xoá vĩnh viễn.
 */

var DEPTH_LIMIT = 8; // số cấp thư mục tối đa khi kiểm một tệp có nằm trong thư mục gốc không
var MAX_BYTES = 21 * 1024 * 1024; // trần cỡ MỘT tệp lưu (giới hạn nghiệp vụ 20 MB, chừa dư); Edge Function đã kiểm trước, đây là lớp chặn thứ hai nếu ai biết URL và mật khẩu
var MIN_FREE_BYTES = 1024 * 1024 * 1024; // luôn chừa ít nhất 1 GB trống trong tài khoản (sao lưu đêm, thư): còn dưới mức này thì từ chối lưu
var NAME_RE = /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$/; // tên thư mục con và tên tệp: không bắt đầu bằng dấu chấm, không dấu cách, không ký tự lạ, không tên học sinh

function out_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function fail_(code, message) {
  return out_({ ok: false, code: code, message: message });
}

/** So mật khẩu không dừng sớm ở ký tự sai đầu tiên (tránh dò từng ký tự theo thời gian phản hồi). */
function secretOk_(given) {
  var expected = PropertiesService.getScriptProperties().getProperty('SECRET') || '';
  if (!expected || typeof given !== 'string' || given.length !== expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff === 0;
}

function rootFolder_() {
  var id = PropertiesService.getScriptProperties().getProperty('ROOT_FOLDER_ID');
  if (!id) throw new Error('THIEU_ROOT');
  return DriveApp.getFolderById(id);
}

/** Tệp hoặc thư mục có nằm trong thư mục gốc không (đi ngược lên các thư mục cha, tối đa DEPTH_LIMIT cấp). */
function inRoot_(item, rootId) {
  var level = [item];
  for (var depth = 0; depth < DEPTH_LIMIT; depth++) {
    var next = [];
    for (var i = 0; i < level.length; i++) {
      var parents = level[i].getParents();
      while (parents.hasNext()) {
        var p = parents.next();
        if (p.getId() === rootId) return true;
        next.push(p);
      }
    }
    if (next.length === 0) return false;
    level = next;
  }
  return false;
}

/** Lấy tệp theo id; chỉ trả khi tệp nằm trong thư mục gốc, ngoài ra coi như không có. */
function fileInRoot_(id) {
  var root = rootFolder_();
  var file;
  try {
    file = DriveApp.getFileById(id);
  } catch (e) {
    return null;
  }
  return inRoot_(file, root.getId()) ? file : null;
}

/** Tìm hoặc tạo chuỗi thư mục con dưới thư mục gốc. Mỗi đoạn tên phải khớp NAME_RE. */
function ensureFolders_(segments) {
  var folder = rootFolder_();
  for (var i = 0; i < segments.length; i++) {
    if (typeof segments[i] !== 'string' || !NAME_RE.test(segments[i])) throw new Error('TEN_SAI');
    var found = folder.getFoldersByName(segments[i]);
    folder = found.hasNext() ? found.next() : folder.createFolder(segments[i]);
  }
  return folder;
}

function doPost(e) {
  var req;
  try {
    req = JSON.parse(e.postData.contents);
  } catch (err) {
    return fail_('YEU_CAU_SAI', 'Yêu cầu không hợp lệ.');
  }
  if (!secretOk_(req.secret)) return fail_('SAI_MAT_KHAU', 'Sai mật khẩu.');
  try {
    switch (req.action) {
      case 'ping':
        return out_({ ok: true, rootName: rootFolder_().getName() });
      case 'quota':
        return out_({ ok: true, usage: DriveApp.getStorageUsed(), limit: DriveApp.getStorageLimit() });
      case 'save': {
        if (typeof req.name !== 'string' || !NAME_RE.test(req.name)) return fail_('TEN_SAI', 'Tên tệp không hợp lệ.');
        if (typeof req.mimeType !== 'string' || typeof req.dataBase64 !== 'string') return fail_('YEU_CAU_SAI', 'Thiếu dữ liệu.');
        // Luật trần cỡ: chuỗi base64 dài hơn mức tương ứng MAX_BYTES thì từ chối, chưa giải mã.
        if (req.dataBase64.length > Math.ceil((MAX_BYTES * 4) / 3) + 4) return fail_('QUA_LON', 'Tệp quá lớn.');
        // Luật chừa dung lượng: sau khi lưu phải còn ít nhất MIN_FREE_BYTES trống.
        var free = DriveApp.getStorageLimit() - DriveApp.getStorageUsed();
        if (free - Math.ceil((req.dataBase64.length * 3) / 4) < MIN_FREE_BYTES) return fail_('HET_CHO', 'Kho đầy, báo quản trị viên.');
        var folder = ensureFolders_(Array.isArray(req.path) ? req.path : []);
        var blob = Utilities.newBlob(Utilities.base64Decode(req.dataBase64), req.mimeType, req.name);
        var file = folder.createFile(blob);
        return out_({ ok: true, id: file.getId(), size: file.getSize() });
      }
      case 'read': {
        var f = fileInRoot_(req.id);
        if (!f) return fail_('KHONG_THAY', 'Không tìm thấy tệp.');
        var b = f.getBlob();
        return out_({ ok: true, mimeType: b.getContentType(), dataBase64: Utilities.base64Encode(b.getBytes()) });
      }
      case 'remove': {
        var g = fileInRoot_(req.id);
        if (!g) return out_({ ok: true, removed: false }); // đã không còn hoặc không thuộc kho: coi như xong, không chạm gì
        // Xoá VĨNH VIỄN (Drive.Files.remove), không phải setTrashed: thùng rác vẫn tính dung lượng.
        Drive.Files.remove(g.getId());
        return out_({ ok: true, removed: true });
      }
      default:
        return fail_('VIEC_SAI', 'Việc không được hỗ trợ.');
    }
  } catch (err2) {
    var m = String(err2 && err2.message ? err2.message : err2);
    if (m === 'TEN_SAI') return fail_('TEN_SAI', 'Tên thư mục không hợp lệ.');
    if (m === 'THIEU_ROOT') return fail_('CHUA_CAU_HINH', 'Chưa đặt thư mục gốc.');
    return fail_('LOI', 'Chưa xử lý được.');
  }
}
