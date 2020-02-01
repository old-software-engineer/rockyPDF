function clearErrors() {
  var isGroup = false;
  var groupInputs = $(this).find("input");
  var parent = null;
  if (groupInputs.length > 0) {
    isGroup = true;
  }
  if (isGroup) {
    parent = $(this);
  } else {
    parent = $(this).parent()
  }
  var errorField = parent.siblings(".error")
  parent.removeClass('has_error') 
  errorField.text('')
}
function validateField(errorMessage) {
  var field = this;
  if (!field) {
    return;
  }
  var isGroup = false;
  var groupInputs = $(this).find("input");
  if (groupInputs.length > 0) {
    isGroup = true;
  }
  var val = ''
  var parent = null;
  if (isGroup) {
    var groupVal = null
    for(var i=0,ii=groupInputs.length;i<ii;i++) {
      var input = groupInputs[i];
      var v = $(input).val()
      if (groupVal == null || groupVal.length > v.length) {
        groupVal = v;
      }
    }
    val = groupVal;
    parent = $(field);
  } else {
    val = $(field).val()
    parent = $(field).parent()
  }
  var errorField = parent.siblings(".error")
  var currentError = errorField.text();
  var messageIdx = currentError.indexOf(errorMessage)
  if (!val || val == '') {
    // Add if not present
    if (messageIdx == -1) {
      errorField.text([currentError, errorMessage].join(" "))
    }       
    parent.addClass('has_error') 
  } else {
    if (messageIdx >= 0) {
      currentError = currentError.split('')
      currentError.splice(messageIdx, errorMessage.length)
      errorField.text(currentError.join(''))
    } 
    //console.log(errorField.text())
    if (errorField.text().replace(/\s/g, '') == '') {
      parent.removeClass('has_error') 
    }
           
  }
}

function validateBooleanField(errorMessage) {
  var field = this;
  if (!field) {
    return
  }
  var val = $(field).is(":checked")
  //console.log(val)
  var parent = $(field).parent()
  var errorField = $(field).siblings(".error")
  var currentError = errorField.text();
  var messageIdx = currentError.indexOf(errorMessage)
  if (!val) {
    // Add if not present
    //console.log("hi", errorMessage, errorField)
    if (messageIdx == -1) {
      errorField.text([currentError, errorMessage].join(" "))
    }       
    parent.addClass('has_error') 
  } else {
    if (messageIdx >= 0) {
      currentError = currentError.split('')
      currentError.splice(messageIdx, errorMessage.length)
      errorField.text(currentError.join(''))
    } 
    //console.log(errorField.text())
    if (errorField.text().replace(/\s/g, '') == '') {
      parent.removeClass('has_error') 
    }
           
  }
}

function initValidations() {
  $("[data-client-validation-required]").each(function() {
    var errorMessage = $(this).data("client-validation-required")
    if (this.tagName == "DIV") {
      $(this).find("input:last-child").blur(validateField.bind(this, errorMessage))
      $(this).find("input:last-child").change(validateField.bind(this, errorMessage))
      $(this).find("input:last-child").keyup(validateField.bind(this, errorMessage))    
      $(this).keydown(clearErrors.bind(this))    
    } else {
      $(this).blur(validateField.bind(this, errorMessage))
      $(this).change(validateField.bind(this, errorMessage))
      $(this).keyup(validateField.bind(this, errorMessage))    
      $(this).keydown(clearErrors.bind(this))    
    }
    
  })
  
  $("[data-client-validation-require-accept]").each(function() {
    var errorMessage = $(this).data("client-validation-require-accept");
    $(this).change(validateBooleanField.bind(this,errorMessage))
  })
  
  var fields = $("input, select, textarea");
  var validatePrevious = function(element) {
    for (var i=0,ii=fields.length;i<ii;i++) {
      var field = fields[i]
      if (field == element) {
        break;
      } else {
        var errorMessage = $(field).data("client-validation-required")  
        if (errorMessage && !errorMessage == '') {
          validateField.bind(field)(errorMessage);
        }      
        errorMessage = $(field).data("client-validation-require-accept")
        if (errorMessage && !errorMessage == '') {
          validateBooleanField.bind(field)(errorMessage)    
        }      
      }
    }
  }
  fields.click(function() { validatePrevious(this) });
  fields.focus(function() { validatePrevious(this) });  
}

