class shoe {
  [int]$size
}

class shoeComparer : System.Collections.Generic.IComparer[Shoe] {
  # [string]$PropertyName
  # [bool]$Descending = $false

  #  ShoeComparer([string]$property) {
  #    $this.PropertyName = $property
  #  }

  # ShoeComparer([string]$property, [bool]$descending) {
  #   $this.PropertyName = $property
  #   $this.Descending = $descending
  # }

  [int]Compare([Shoe]$a, [Shoe]$b) {
    $res = if ($a.$($this.PropertyName) -eq $b.$($this.PropertyName)) {
      0
    }
    elseif ($a.$($this.PropertyName) -lt $b.$($this.PropertyName)) {
      -1
    }
    else {
      1
    }

    if ($this.Descending) {
      $res *= -1
    }

    return $res
  }
}
