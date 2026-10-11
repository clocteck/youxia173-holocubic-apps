-- Web controller lease. Does not alter Bluetooth pairing or saved mappings.
return function(now)
  local R = { owner=nil, buttons=0, sequence=-1, deadline=0, timeout_ms=8000 }
  function R.expire()
    if R.owner and now() >= R.deadline then
      R.owner=nil; R.buttons=0; R.sequence=-1; R.deadline=0
      return true
    end
    return false
  end
  function R.state()
    return { active=R.owner~=nil, client=R.owner or "", buttons=R.buttons,
      seq=R.sequence, timeout_ms=R.timeout_ms,
      remaining_ms=R.owner and math.max(0,R.deadline-now()) or 0 }
  end
  function R.apply(doc)
    R.expire()
    if type(doc)~="table" or type(doc.client)~="string" or #doc.client<8 or #doc.client>80
      or not doc.client:match("^[%w_%-]+$") then
      return nil,"Invalid client",400
    end
    local seq,buttons=doc.seq,doc.buttons
    if type(seq)~="number" or seq<0 or seq%1~=0 or seq>2147483647
      or type(buttons)~="number" or buttons<0 or buttons>65535 or buttons%1~=0 then
      return nil,"Invalid sequence or buttons",400
    end
    if R.owner~=doc.client then
      if doc.takeover~=true or doc.release==true then return nil,"Control belongs to another session or has expired",409 end
      R.owner=doc.client; R.sequence=-1; R.buttons=0
    end
    if seq<=R.sequence then return nil,"Stale input",409 end
    R.sequence=seq
    if doc.release==true then
      R.owner=nil; R.buttons=0; R.deadline=0
    else
      R.buttons=buttons; R.deadline=now()+R.timeout_ms
    end
    return true
  end
  function R.overlay(output)
    if not R.owner then return end
    output.connected=true; output.buttons=R.buttons
    output.lx=0; output.ly=0; output.rx=0; output.ry=0; output.lt=0; output.rt=0
    output.name="Web Controller"; output.device_id="web:"..R.owner
  end
  return R
end
