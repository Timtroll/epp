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
	window.document.getElementById('id_'+cnt).className = 'mess';
	window.document.getElementById('status_'+cnt).className = 'mess';
	window.document.getElementById('title_'+cnt).className = 'mess';
	window.document.getElementById('titl_'+cnt).className = 'mess';
	window.document.getElementById('tit_'+cnt).className = 'mess';
	window.document.getElementById('text_'+cnt).className = 'mess';
	window.document.getElementById('textl_'+cnt).className = 'mess';
	window.document.getElementById('date_'+cnt).className = 'mess';
	window.document.getElementById('message').className = 'hide';
	window.document.getElementById('status_'+cnt).innerHTML = 'old';
}
function AddInput (nam) {
	var count = nam + '_count';
	cnt = document.getElementById(count).value;
	namer = nam + '_new';
	var place = document.getElementById(namer);
	var elem = document.createElement("li");
	var newinput = document.createElement("input");
	newinput.id = nam + '_' + cnt;
	newinput.name = nam + '_' + cnt;
	newinput.type = 'text';
	newinput.className = 'dump-edit';
	elem.appendChild(newinput);
	place.appendChild(elem);
	document.getElementById('sceleton').value = document.getElementById('sceleton').value + ' ' + nam + '_' + cnt;
	cnt = ++cnt;
//alert(cnt);
	document.getElementById(count).value = cnt;
}
