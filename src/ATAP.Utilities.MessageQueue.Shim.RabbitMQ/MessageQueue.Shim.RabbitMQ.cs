using System;
using System.Collections.Generic;
using System.Threading;

using ATAP.Utilities.MessageQueue;
using Polly;

using RabbitMQ.Client;
using RabbitMQ.Client.Events;

using Serilog;

namespace ATAP.Utilities.MessageQueue.Shim.RabbitMQT {

  public interface IRabbitMQMessageServerOptions : IMessageQueueOptions {
    public Uri? Uri { get; set; }
    public string HostName { get; set; }
    public int Port { get; set; }
    public string UserName { get; set; }
    public string Password { get; set; }
  }

  public class RabbitMQMessageServerOptions : MessageQueueOptionsAbstract, IRabbitMQMessageServerOptions {
    public Uri? Uri { get; set; }
    public string HostName { get; set; }
    public int Port { get; set; }
    public string UserName { get; set; }
    public string Password { get; set; }
  }
  public interface IRabbitMQMessageQueueOptions : IMessageQueueOptions {
    public string QueueName { get; set; }
    public bool Durable { get; set; }
    public bool Exclusive { get; set; }
    public bool AutoDelete { get; set; }
    public IDictionary<string, object> Arguments { get; set; }
  }

  public class RabbitMQMessageQueueOptions : MessageQueueOptionsAbstract, IRabbitMQMessageQueueOptions {
    public string QueueName { get; set; }
    public bool Durable { get; set; }
    public bool Exclusive { get; set; }
    public bool AutoDelete { get; set; }
    public IDictionary<string, object> Arguments { get; set; }
  }

  public class RabbitMQMessageQueue<TSendMessageResults> : MessageQueueAbstract<TSendMessageResults> where TSendMessageResults : ISendMessageResultsAbstract,  new() {

    public RabbitMQMessageServerOptions RabbitMQMessageServerOptions { get; set; }
    public RabbitMQMessageQueueOptions RabbitMQMessageQueueOptions { get; set; }
    public IModel Channel { get; set; }
    public IConnection Connection { get; set; }

    //public Func<Byte[], TSendMessageResults> SendFunc { get; init; }
    //public Func<IEnumerable<IEnumerable<Byte[]>>, TSendMessageResults> SendEnumerableFunc { get; init; }
    //public Func<IDictionary<string, IEnumerable<Byte[]>>, TSendMessageResults> SendDictionaryFunc { get; init; }
    //public Action<Byte[]> ReceiveAction { get; init; }
    //public Action<IEnumerable<Byte[]>> ReceiveEnumerableAction { get; init; }
    //public Action<IDictionary<string, IEnumerable<Byte[]>>> ReceiveDictionaryAction { get; init; }

    public RabbitMQMessageQueue(IRabbitMQMessageServerOptions rabbitMQMessageServerOptions, IRabbitMQMessageQueueOptions rabbitMQMessageQueueOptions, Action<Byte[]> receiveAction) : this(rabbitMQMessageServerOptions, rabbitMQMessageQueueOptions, receiveAction, null) { }

    public RabbitMQMessageQueue(IRabbitMQMessageServerOptions rabbitMQMessageServerOptions, IRabbitMQMessageQueueOptions rabbitMQMessageQueueOptions, Action<Byte[]> receiveAction, CancellationToken? cancellationToken) : base(receiveAction, cancellationToken) {
      if (rabbitMQMessageServerOptions != null) {
        RabbitMQMessageServerOptions = (RabbitMQMessageServerOptions)rabbitMQMessageServerOptions;
      }
      else {
        RabbitMQMessageServerOptions = new RabbitMQMessageServerOptions() {
          // Default set of RabbitMQ Server Connection options, matching RabbitMQ default setup and tutorials. Hardcoded here. Or if used in a DI context, there might be a configurationRoot and String Constants to get the values from
          // Anything that is not initialized is implicitly null
          // QueueNames
          // Uri("amqp://guest:guest@localhost:5672/");
          HostName = "localhost",
          Port = 5672,
          UserName = "svc_VAPlugin",
          Password = "pass12345" // ToDo: Figure out how to integrate UserSecrets
        };
      }
      if (rabbitMQMessageQueueOptions != null) {
        RabbitMQMessageQueueOptions = (RabbitMQMessageQueueOptions)rabbitMQMessageQueueOptions;
      }
      else {
        RabbitMQMessageQueueOptions = new RabbitMQMessageQueueOptions() {
          // Default set of RabbitMQ Queue specific options, matching RabbitMQ default setup and tutorials. Hardcoded here. Or if used in a DI context, there might be a configurationRoot and String Constants to get the values from
          // Anything that is not initialized is implicitly null
          // QueueNames
          // Uri("amqp://guest:guest@localhost:5672/");
          QueueName = "ATAP.Utilities.MessageQueue.RabbitMQDefaultQueueName",  // ToDo: put into constants  // eventually from DI-injected ConfigurationRoot
          Durable = false,
          Exclusive = false,
          AutoDelete = false,
          Arguments = new Dictionary<string, object>()
        };
      }
      CreateConnection();
      CreateChannel();
      DeclareQueue(queueName: "ATAP.Utilities.VoiceAttack.Game.AOE.OperationsQueue", durable: false, exclusive: false, autoDelete: false, arguments: null);
    }

    public TSendMessageResults SendMessage(Byte[] message) {
      if (message == null) { throw new ArgumentNullException(nameof(message)); }
      Channel.BasicPublish(exchange: "", routingKey: RabbitMQMessageQueueOptions.QueueName, basicProperties: null, body: message);
      //Serilog.Log.Debug("{0} {1}: Message sent {2}", "PluginVA", "SendToMQ.SendMessage", message);

      return new TSendMessageResults() { Success = true };    // Basic RabbitMQ publish has nothing to return // Later bindings will return at least the ack for more sophisticated messagequeue
    }
    public void ExecuteReceiveMessageAction(Byte[] message) {
      // Wrap in try catch and/or  Polly
      base.ReceiveAction.Invoke(message);
    }

    // ToDo: add a Configure which has default values of the RabbitMQMessageServerOptionsCurrent should come from an IConfiguration object, and keys/default values should come from a StringConstants
    // ToDo: ConvertOptions should be expanded to include a set of extensions for RabbitMQMessageServerOptions class to promote reuse of the instance

    public void Configure() { }

    private void CreateConnection() { //}, URI? uRI = new Uri("amqp://guest:guest@localhost:5672/")) {
      Serilog.Log.Debug("{0} {1}: MethodEntry", "RabbitMQMessageQueue", "CreateConnection");

      /// ToDo: add additional permutations
      var factory = new ConnectionFactory() {
        //Uri = new Uri("amqp://guest:guest@localhost:5672/");
        HostName = RabbitMQMessageServerOptions.HostName,
        Port = RabbitMQMessageServerOptions.Port,
        UserName = RabbitMQMessageServerOptions.UserName,
        Password = RabbitMQMessageServerOptions.Password // ToDo: Figure out how to integrate UserSecrets
      };
      // Use Polly for retry logic
      var retryPolicy = Policy.Handle<RabbitMQ.Client.Exceptions.BrokerUnreachableException>()
          .WaitAndRetry(retryCount: 3, sleepDurationProvider: _ => TimeSpan.FromMilliseconds(250));
      //Execute the factory's CreateConnection wrapped in  retry policy
      var attempt = 0;
      retryPolicy.Execute(() => {
        Serilog.Log.Debug("{0} {1}: attempt {2} at CreateConnection", "RabbitMQMessageQueue", "CreateConnection", attempt++);
        Connection = factory.CreateConnection();
      });

    }
    public void CreateChannel() {
      //ToDO: wrap with Polly
      Channel = Connection.CreateModel();
    }
    public void DeclareQueue(string queueName, bool durable, bool exclusive, bool autoDelete, IDictionary<string, object> arguments) {
      //ToDO: wrap with Polly
      //Execute the Channel's QueueDeclare wrapped in  retry policy
      Channel.QueueDeclare(queue: RabbitMQMessageQueueOptions.QueueName, durable: RabbitMQMessageQueueOptions.Durable, exclusive: RabbitMQMessageQueueOptions.Exclusive, autoDelete: RabbitMQMessageQueueOptions.AutoDelete, arguments: RabbitMQMessageQueueOptions.Arguments);
    }

    #region IDisposable Support
    private bool disposedValue = false; // To detect redundant calls
    protected virtual void Dispose(bool disposing) {
      if (!disposedValue) {
        if (disposing) {
          Channel.Dispose();
          Connection.Dispose();
        }
        disposedValue = true;
      }
    }
    // This code added to correctly implement the disposable pattern.
    public void Dispose() {
      // Do not change this code. Put cleanup code in Dispose(bool disposing) above.
      Dispose(true);
    }
    #endregion

  }
}

