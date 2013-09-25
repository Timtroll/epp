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
//alert(command +'=' + document.getElementById(command).value);
	document.getElementById(form).submit();
}
function MarkRead (cnt) {
	window.document.getElementById('id_'+cnt).className = 'mess';
	window.document.getElementById('status_'+cnt).className = 'mess';
	window.document.getElementById('title_'+cnt).className = 'mess';
	window.document.getElementById('titl_'+cnt).className = 'mess';
	window.document.getElementById('tit_'+cnt).className = 'mess';
	window.document.getElementById('text_'+cnt).className = 'mess';
	window.document.getElementById('message').className = 'hide';
}
function get_massages (url) {
	window.document.getElementById('modalframe').innerHTML = "<iframe class='modal' " + "src='" + url + "?get_messages=1'  width='100%' height='100%' frameBorder='0' style='border: 0;display:none;'></iframe>"
}

