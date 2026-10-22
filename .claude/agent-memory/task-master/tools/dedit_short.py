"""dedit variant (rp-u6 fix2): shortest unique anchors (14+ chars, word-start), ~~~ fences, trailing-newline safe. Same diff_edits(e, path, old, new, log) API as dedit.py."""
import difflib,sys
sys.path.insert(0,'/home/sebas/AntiSlop/.claude/agent-memory/task-master/tools'); sys.dont_write_bytecode=True
import cg
from cg import Edits
MAXN=76
def _fence(lines):
    f='~~~'
    while any(l.strip().startswith(f) for l in lines): f+='~'
    return f
def _payload(self,key,lines):
    f=_fence(lines); self.out.append(f'   {key}:'); self.out.append(f); self.out.extend(lines); self.out.append(f)
Edits._payload=_payload
def short(cur,line):
    s=line.strip(); n=len(s)
    for L in range(14,n+1):
        for st in range(0,n-L+1):
            if st and s[st-1]!=' ': continue
            sub=s[st:st+L]
            if '`' in sub or sub.endswith(' ') or sub.endswith('\\'): continue
            if sum(1 for l in cur if sub in l)==1: return sub
    return None
def clean(cur,line):
    s=line.strip()
    if not s or '`' in s or s.endswith('\\'): return None
    return short(cur,line)
def diff_edits(e,path,old_text,new_text,log):
    old_text=old_text.rstrip('\n'); new_text=new_text.rstrip('\n'); old=old_text.split('\n'); new=new_text.split('\n'); cur=list(old); off=0
    for tag,i1,i2,j1,j2 in difflib.SequenceMatcher(None,old,new,autojunk=False).get_opcodes():
        if tag=='equal': continue
        add=new[j1:j2]; p1,p2=i1+off,i2+off
        if tag=='insert':
            k=p1-1
            while k>=0 and clean(cur,cur[k]) is None: k-=1
            assert k>=0
            if k==p1-1:
                after=cur[:p1]+add+cur[p1:]; anc=clean(cur,cur[k]); i=0
                while i<len(add):
                    j=len(add) if len(add)-i<=MAXN else i+MAXN
                    if j<len(add):
                        while j>i+10 and clean(after,add[j-1]) is None: j-=1
                        assert j>i+10
                    chunk=add[i:j]
                    e.out+= [f'{e.n}. file: `{path}`',f'   anchor: line matching `{anc}`','   indent: 0']; e._payload('insert-after',chunk)
                    log.append((e.n,'insert',chunk)); e.n+=1
                    if j<len(add): anc=clean(after,chunk[-1])
                    i=j
                cur[p1:p1]=add; off+=len(add); continue
            lo,hi=k,p1
        else:
            lo,hi=p1,p2; flip=0
            while not any(clean(cur,cur[q]) for q in range(lo,hi)):
                if flip%2==0 and lo>0: lo-=1
                elif hi<len(cur): hi+=1
                flip+=1; assert flip<60
        before=cur[lo:hi]; aft=cur[lo:p1]+add+cur[p2:hi] if tag!='insert' else before+add
        assert '\n'.join(cur).count('\n'.join(before))==1
        anc=next(clean(cur,l) for l in before if clean(cur,l))
        assert len(aft)<=MAXN
        e.out+= [f'{e.n}. file: `{path}`',f'   anchor: line matching `{anc}`','   indent: 0']; e._payload('before',before); e._payload('after',aft)
        log.append((e.n,tag,aft)); e.n+=1
        cur[p1 if tag=='insert' else p1:p2]=add; off+=len(add)-(i2-i1)
    assert '\n'.join(cur)==new_text
