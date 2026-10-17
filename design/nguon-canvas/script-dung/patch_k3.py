p='live15/project/K3.dc.html'; s=open('fresh4/project/K3.dc.html',encoding='utf-8').read()
def rep(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:70],s.count(a)); s=s.replace(a,b)
rep('<div class="hmt-act" style="flex-direction:column;gap:var(--space-2)">','<div class="hmt-act" style="{{ a.rowStyle }}">')
rep('<div class="hmt-act-main"><b>{{ a.typ }} · {{ a.title }}</b>','<div class="hmt-act-main"><b style="{{ a.ttlStyle }}">{{ a.typ }} · {{ a.title }}</b>')
rep('<span class="hmt-tag">Mới</span></div>\n<div class="hmt-act-btns" style="padding-left:24px"><button class="hmt-btn" type="button" onClick="{{ a.done }}">','<span class="{{ a.tagCls }}">{{ a.stTxt }}</span></div>\n<div class="hmt-act-btns" style="padding-left:24px"><sc-if value="{{ a.open }}" hint-placeholder-val="{{ true }}"><button class="hmt-btn" type="button" onClick="{{ a.done }}">') if False else None
i=s.index('<span class="hmt-tag">Mới</span></div>\n<div class="hmt-act-btns"'); j=s.index('</div></div></sc-for>',i)
blk=s[i:j]
head='<span class="hmt-tag">Mới</span></div>\n<div class="hmt-act-btns" style="padding-left:24px">'
assert blk.startswith(head)
btns=blk[len(head):]
new='<span class="{{ a.tagCls }}">{{ a.stTxt }}</span></div>\n<div class="hmt-act-btns" style="padding-left:24px"><sc-if value="{{ a.open }}" hint-placeholder-val="{{ true }}">'+btns+'</sc-if><sc-if value="{{ a.asking }}" hint-placeholder-val="{{ false }}"><span class="hmt-help" style="align-self:center">Lý do huỷ:</span><sc-for list="{{ a.whys }}" as="w" hint-placeholder-count="3"><button class="hmt-btn hmt-btn-sm" type="button" onClick="{{ w.pick }}">{{ w.label }}</button></sc-for><button class="hmt-btn hmt-btn-sm" type="button" onClick="{{ a.cancelAsk }}">Đóng</button></sc-if><sc-if value="{{ a.closed }}" hint-placeholder-val="{{ false }}"><button class="hmt-btn" type="button" title="Bấm nhầm? Mở lại để làm tiếp" onClick="{{ a.reopen }}">Mở lại</button><span class="hmt-help" style="align-self:center">{{ a.whyTxt }}</span></sc-if>'
s=s[:i]+new+s[j:]
rep('<span>{{ toast }}</span></div></sc-if>','<span>{{ toast }}</span><sc-if value="{{ undo }}" hint-placeholder-val="{{ false }}"><button type="button" onClick="{{ doUndo }}" style="margin-left:10px;background:none;border:0;color:inherit;text-decoration:underline;cursor:pointer;font:inherit">Hoàn tác (8s)</button></sc-if></div></sc-if>')
rep("""  closeAct(id, verb) {
    const s = this.state;
    const a = s.acts.find((x) => x.id === id);
    this.setState({ acts: s.acts.filter((x) => x.id !== id) });
    this.addEvent({ ini: 'HT', sys: true, who: 'Hệ thống', kind: 'Hệ thống', text: 'Trần Thu Hà ' + verb + ': ' + a.typ + ' · ' + a.title });
    this.flash('Đã ' + verb);
  }""","""  closeAct(id, verb, why) {
    const s = this.state;
    const a = s.acts.find((x) => x.id === id);
    const st = /^huỷ/.test(verb) ? 'Huỷ' : 'Hoàn thành';
    this.setState({ acts: s.acts.map((x) => (x.id === id ? Object.assign({}, x, { st: st, why: why || '', ask: false }) : x)) });
    this.addEvent({ ini: 'HT', sys: true, who: 'Hệ thống', kind: 'Hệ thống', text: 'Trần Thu Hà ' + verb + ': ' + a.typ + ' · ' + a.title + (why ? ' (lý do: ' + why + ')' : '') });
    this.flash('Đã ' + verb + '. Bấm nhầm thì hoàn tác hoặc mở lại.', id, 8000);
  }
  askAct(id, on) {
    this.setState((s) => ({ acts: s.acts.map((x) => (x.id === id ? Object.assign({}, x, { ask: on }) : x)) }));
  }
  reopenAct(id, quiet) {
    const s = this.state;
    const a = s.acts.find((x) => x.id === id);
    this.setState({ acts: s.acts.map((x) => (x.id === id ? Object.assign({}, x, { st: '', why: '', ask: false }) : x)) });
    this.addEvent({ ini: 'HT', sys: true, who: 'Hệ thống', kind: 'Hệ thống', text: 'Trần Thu Hà ' + (quiet ? 'hoàn tác' : 'mở lại') + ' hoạt động: ' + a.typ + ' · ' + a.title + ' (về “Chưa làm”)' });
    this.flash(quiet ? 'Đã hoàn tác, hoạt động về “Chưa làm”.' : 'Đã mở lại hoạt động, trạng thái “Chưa làm”.');
  }""")
rep("""  flash(msg) {
    this.setState({ toast: msg });
    clearTimeout(this._t);
    this._t = setTimeout(() => this.setState({ toast: '' }), 2600);""","""  flash(msg, undoId, ms) {
    this.setState({ toast: msg, undoId: undoId || 0 });
    clearTimeout(this._t);
    this._t = setTimeout(() => this.setState({ toast: '', undoId: 0 }), ms || 2600);""")
rep("""const acts = s.acts.map((a) => ({
      id: a.id, typ: a.typ, title: a.title, when: a.when, who: a.who, late: a.late, onTime: !a.late,""","""const WHYS = ['PH báo bận', 'Không liên lạc được', 'Tạo nhầm'];
    const acts = s.acts.map((a) => ({
      id: a.id, typ: a.typ, title: a.title, when: a.when, who: a.who, late: a.late && !a.st, onTime: !a.late || !!a.st,
      open: !a.st && !a.ask, asking: !a.st && !!a.ask, closed: !!a.st, stTxt: a.st || 'Chưa làm', tagCls: 'hmt-tag' + (a.st === 'Hoàn thành' ? ' hmt-tag-success' : ''),
      rowStyle: 'flex-direction:column;gap:var(--space-2)' + (a.st === 'Huỷ' ? ';opacity:.75' : ''), ttlStyle: a.st === 'Huỷ' ? 'text-decoration:line-through' : '',
      whys: WHYS.map((w) => ({ label: w, pick: () => this.closeAct(a.id, 'huỷ hoạt động', w) })), whyTxt: a.st === 'Huỷ' && a.why ? 'Lý do: ' + a.why : '',
      cancelAsk: () => this.askAct(a.id, false), reopen: () => this.reopenAct(a.id, false),""")
rep("cancel: () => this.closeAct(a.id, 'huỷ hoạt động')\n    }));","cancel: () => this.askAct(a.id, true)\n    }));")
rep("const nextAct = s.acts.filter((a) => !a.late)[0];","const nextAct = s.acts.filter((a) => !a.late && !a.st)[0];")
rep("nAppt: s.acts.length,","nAppt: s.acts.filter((a) => !a.st).length,")
rep("acts, nActs: s.acts.length, noActs: s.acts.length === 0,","acts, nActs: s.acts.filter((a) => !a.st).length, noActs: s.acts.filter((a) => !a.st).length === 0, undo: !!s.undoId, doUndo: () => this.reopenAct(s.undoId, true),")
open(p,'w',encoding='utf-8').write(s); print('ok')
