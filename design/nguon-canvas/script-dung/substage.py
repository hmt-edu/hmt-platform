import re,glob,json
SUB={
'L2':['L2A Không nghe máy','L2B Không liên lạc được','L2C Bận gọi lại sau'],
'L3':['L3A Không có nhu cầu','L3B Chưa có nhu cầu ở thời điểm hiện tại','L3C Đang học ở nơi khác','L3D Không phù hợp về sản phẩm','L3E Không phù hợp về giá','L3F Không phù hợp về độ tuổi','L3G Không phù hợp về địa điểm','L3H Không nghe máy nhiều lần'],
'L4':['L4A Tiềm năng, cần gửi thêm thông tin','L4B Tiềm năng, cần tư vấn thêm','L4C Tiềm năng, cần tham khảo ý kiến','L4D Tiềm năng, cần gọi lại vào dịp khác'],
'L5':['L5A Đồng ý tham gia test','L5B Đã xếp lịch test','L5P Đã làm bài, chờ giáo viên chấm','L5C Huỷ test, không liên hệ được','L5D Huỷ test, PH bận không đưa đón được','L5E Huỷ test, con bận không tham gia được','L5F Huỷ test, con không muốn tham gia','L5G Huỷ test, con đang ôn thi','L5H Huỷ test, con ốm','L5I Huỷ test, gia đình đi du lịch','L5K Huỷ test, thời tiết không thuận lợi','L5N Huỷ test, con đang ở quê','L5M Huỷ test, lý do khác','L5O Huỷ test nhiều lần','L5Q Huỷ test, trung tâm không xếp được lịch'],
'L6':['L6A Có kết quả, cần phân loại','L6B Học xuất sắc','L6C Học tốt','L6D Học khá','L6E Học trung bình','L6F Học yếu'],
'L7':['L7A Cần đặt lịch tư vấn','L7B Đã tư vấn, khách hàng tiềm năng','L7C Đã tư vấn, dự thu','L7D Đã tư vấn, cần trao đổi thêm','L7E Đã tư vấn, PH cân nhắc học phí','L7F Đã tư vấn, PH cân nhắc chương trình học','L7G Đã tư vấn, PH cân nhắc thời gian học','L7H Đã tư vấn, PH cân nhắc địa điểm học','L7I Đã tư vấn, PH cân nhắc hình thức học','L7K Đã tư vấn, PH cần trao đổi với người thân','L7L Đã tư vấn, PH cần trao đổi với con'],
'L8':['L8A PH đặt cọc','L8B PH thanh toán chia để trả','L8C PH hoàn thành 100% học phí']}
FULL={x.split(' ',1)[0]:x for v in SUB.values() for x in v}
OLD={'L4A Cần gửi thêm thông tin':'L4A Tiềm năng, cần gửi thêm thông tin','L4B Cần tư vấn thêm':'L4B Tiềm năng, cần tư vấn thêm','L4C Cần tham khảo ý kiến':'L4C Tiềm năng, cần tham khảo ý kiến','L7E PH cân nhắc học phí':'L7E Đã tư vấn, PH cân nhắc học phí'}
LSUB_JS='const L_SUB = '+json.dumps(SUB,ensure_ascii=False)+';'
GETSUBS='  getSubs() {\n    return {\n'+',\n'.join('      %s: [%s]'%(k[1],', '.join("['%s', '%s']"%(x.split(' ',1)[0],x) for x in v)) for k,v in SUB.items())+'\n    };\n  }'
if __name__=='__main__':
    files=sorted(glob.glob('live15/project/TS*.dc.html'))+['scripts/ts09_base.dc.html','scripts/build_ts09v.py','scripts/build_ts04_10.py','scripts/ts16_common.js','scripts/ts16b_logic.js','scripts/ts16c_logic.js','scripts/k11c_logic.js']
    for f in files:
        s=open(f).read(); o=s
        s=re.sub(r"const L_SUB = \{.*?\};",LSUB_JS.replace('\\','\\\\'),s,count=1,flags=re.S)
        s=re.sub(r"  getSubs\(\) \{\n    return \{\n.*?\n    \};\n  \}",GETSUBS,s,count=1,flags=re.S)
        for a,b in OLD.items(): s=s.replace(a,b)
        if s!=o: open(f,'w').write(s); print('patched',f)
