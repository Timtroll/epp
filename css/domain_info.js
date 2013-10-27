function open_frame (url) {
	window.document.getElementById('modalframe').innerHTML = "<iframe " + "src='" + url + "'  width='100%' height='100%' frameBorder='0' style='border: 0'></iframe>"
}
function PostData (obj, form, command) {
	var elm = document.createElement("input"); 
	elm.type = "hidden";
	elm.name = command;
	elm.id = command;
	elm.value = 1;
	obj.appendChild(elm);
//alert(form+'='+command+'='+document.getElementById(command).value);
	document.getElementById(form).submit();
}
function MarkRead (cnt) {
	var items = new Array('id_', 'date_', 'titl_', 'tit_', 'title_', 'text_', 'textl_', 'prev_', 'status_');
	for(var i=0; i < items.length; i++) {
		window.document.getElementById(items[i]+cnt).className = 'mess';
	}

	window.document.getElementById('message').className = 'hide';
	window.document.getElementById('status_'+cnt).innerHTML = 'old';
}
function AddInput(obj, nam) {
	var cnt = document.getElementById(nam+'_count').value;
	var new_input=document.createElement('li');
	new_input.innerHTML='<u onclick="DelInput(this.parentNode, \''+nam+'\')">x</u>';
	new_input.innerHTML=new_input.innerHTML+'<input name="'+ nam +'_'+cnt+'" class="dump-edit">';
	new_input.innerHTML=new_input.innerHTML+'<b onclick="AddInput(this.parentNode, \''+nam+'\')">+<b>';
	if (obj.nextSibling) {
		document.getElementById(nam).insertBefore(new_input,obj.nextSibling)
	}
	else {
		document.getElementById(nam).appendChild(new_input);
	}
	document.getElementById('sceleton').value = document.getElementById('sceleton').value + ' ' + nam + '_' + cnt;
	cnt = ++cnt;
	document.getElementById(nam+'_count').value = cnt;
}
function DelInput(obj, nam) {
	document.getElementById(nam).removeChild(obj)
}