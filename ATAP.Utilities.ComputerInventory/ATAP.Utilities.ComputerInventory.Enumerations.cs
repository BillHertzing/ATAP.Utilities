<<<<<<< HEAD:ATAP.Utilities.ComputerInventory/ATAP.Utilities.ComputerInventory.Enumerations.cs
﻿using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
=======
using ServiceStack.Text;
using ServiceStack.Text.EnumMemberSerializer;
>>>>>>> RefactorCryptoCurrencyToExtractDTOs:ATAP.Utilities.ComputerInventory.Enumerations/ATAP.Utilities.ComputerInventory.Enumerations.cs
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Text;

namespace ATAP.Utilities.ComputerInventory
{


    public enum GPUMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("AMD")]
        AMD,
        [Description("NVIDEA")]
        NVIDEA
    }

    public enum VideoCardMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("ASUS")]
        ASUS,
        [Description("EVGA")]
        EVGA,
        [Description("MSI")]
        MSI,
        [Description("PowerColor")]
        PowerColor
    }

    public enum MainBoardMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("ASUS")]
        ASUS,
        [Description("MSI")]
        MSI
    }

    public enum CPUMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("Intel")]
        Intel,
        [Description("AMD")]
        AMD
    }

    public enum VideoCardMemoryMaker
    {
        //ToDo: Add [LocalizedDescription("Generic", typeof(Resource))]
        [Description("Generic")]
        Generic,
        [Description("Elpida")]
        Elpida,
        [Description("Hynix")]
        Hynix,
        [Description("Samsung")]
        Samsung
    }
}
