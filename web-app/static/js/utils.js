var readingText = "Excuse me, does the rent include gas, water and electricity?"

var changeTextButton = document.getElementById("changeTextButton");
var inputTextButton = document.getElementById("inputTextButton");
var inputContainer = document.getElementById("inputContainer");


inputTextButton.addEventListener("click", createNewElement);
var userCustomText;

function createNewElement(){
    inputContainer.innerHTML=`
    <form>
        <div class="form-group">
            <label for="exampleFormControlTextarea1">Your custom text:</label>
            <textarea class="form-control" id="exampleFormControlTextarea1" rows="3"></textarea>
        </div>
        <button type="submit" class="btn btn-primary" onclick="updateTextBox()">Submit</button>
    </form>`;

    changeTextButton.classList.add("hidden");
    inputTextButton.classList.add("hidden");

}


function updateTextBox(){
    userCustomText = document.getElementById("exampleFormControlTextarea1").value;
    readingText = userCustomText;
    inputContainer.innerHTML=userCustomText;
    changeTextButton.classList.remove("hidden");
    inputTextButton.classList.remove("hidden");
}

